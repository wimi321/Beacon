import { Capacitor } from '@capacitor/core';
import { Device } from '@capacitor/device';
import { Geolocation } from '@capacitor/geolocation';
import { Haptics, ImpactStyle } from '@capacitor/haptics';
import { Network } from '@capacitor/network';
import { Preferences } from '@capacitor/preferences';
import type {
  BatteryStatus,
  EvidenceBundle,
  ModelDescriptor,
  ModelDownloadProgress,
  PowerMode,
  RuntimeDiagnostics,
  SosRequest,
  SosState,
  TriageRequest,
  TriageResponse,
} from './types';
import type { BeaconBridge, StreamChunk } from './beaconBridge';
import { NativeBeacon } from './nativeBeaconPlugin';
import {
  buildGroundingContext,
  estimateSosState,
  retrieveEvidenceBundle,
  warmKnowledgeEngine,
} from './beaconEngine';
import {
  hasMeaningfulModelText,
  splitModelResponseText,
} from './modelText';
import { translateMessage } from '../i18n/translate';

const STORAGE_KEYS = {
  powerMode: 'beacon.powerMode',
  sosState: 'beacon.sosState',
  lastSosPacket: 'beacon.lastSosPacket',
} as const;

const BATTERY_WARNING_CODE = 'battery.low_power_emergency' as const;
const VISUAL_ASSIST_CATEGORY =
  'Visual Help / 视觉求助 / wound bleeding bite sting snake spider tick burn rash plant animal fracture poisoning';
const VISUAL_ASSIST_PROMPT_WITH_IMAGE = 'What dangers do you see and what should I do next?';
const VISUAL_ASSIST_PROMPT_WITHOUT_IMAGE = 'What visible details should I check and what should I do next?';

function normalizeLocale(locale?: string): string {
  return locale?.trim() || 'en';
}

function localizeBatteryWarning(locale: string): string {
  return translateMessage(locale, 'warning.battery_low');
}

async function safeImpact(style: ImpactStyle): Promise<void> {
  try {
    await Haptics.impact({ style });
  } catch {
    // Optional haptics.
  }
}

async function readJson<T>(key: string): Promise<T | null> {
  const { value } = await Preferences.get({ key });
  if (!value) {
    return null;
  }

  try {
    return JSON.parse(value) as T;
  } catch {
    return null;
  }
}

async function writeJson(key: string, value: unknown): Promise<void> {
  await Preferences.set({ key, value: JSON.stringify(value) });
}

function createStreamId(): string {
  const randomId = globalThis.crypto?.randomUUID?.();
  if (randomId) {
    return `triage-${randomId}`;
  }
  return `triage-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

export function canUseCapacitorBridge(): boolean {
  return Capacitor.isNativePlatform();
}

class CapacitorBeaconBridge implements BeaconBridge {
  private powerMode: PowerMode = 'normal';
  private sosState: SosState = { active: false, connectedPeers: 0 };
  private models: ModelDescriptor[] = [];
  private lastLocale = 'en';

  async initialize(): Promise<void> {
    await warmKnowledgeEngine();
    const [storedPowerMode, storedSosState] = await Promise.all([
      readJson<PowerMode>(STORAGE_KEYS.powerMode),
      readJson<SosState>(STORAGE_KEYS.sosState),
    ]);

    if (storedPowerMode === 'normal' || storedPowerMode === 'doomsday') {
      this.powerMode = storedPowerMode;
    }

    if (storedSosState) {
      this.sosState = storedSosState;
    }

    await Network.getStatus().catch(() => null);

    try {
      const result = await NativeBeacon.listModels();
      this.models = result.models;
    } catch {
      this.models = [];
    }
  }

  private getActiveModelId(): string | undefined {
    return this.models.find((model) => model.isLoaded)?.id;
  }

  private buildTriageResponse(
    result: { text: string; usedProfileName?: string },
    evidence: EvidenceBundle,
  ): TriageResponse {
    const parsed = splitModelResponseText(result.text);
    const response: TriageResponse & { rawText?: string } = {
      summary: parsed.summary,
      steps: parsed.steps,
      disclaimer:
        evidence.authoritative.length > 0
          ? translateMessage(this.lastLocale, 'disclaimer.authoritative')
          : translateMessage(this.lastLocale, 'disclaimer.limited_evidence'),
      isKnowledgeBacked: evidence.authoritative.length > 0,
      guidanceMode: 'grounded',
      evidence,
      usedProfileName: result.usedProfileName ?? 'Gemma 4 E2B',
    };
    response.rawText = result.text;
    return response;
  }

  private async invokeNativeModel(
    mode: 'triage' | 'visual',
    request: TriageRequest,
  ): Promise<TriageResponse> {
    await warmKnowledgeEngine();
    const evidence = retrieveEvidenceBundle(request);
    const result = await (mode === 'visual' ? NativeBeacon.analyzeVisual : NativeBeacon.triage)({
      modelId: this.getActiveModelId(),
      userText: request.userText,
      categoryHint: request.categoryHint,
      powerMode: request.powerMode,
      imageBase64: request.imageBase64,
      locale: request.locale,
      sessionId: request.sessionId,
      resetContext: request.resetContext,
      groundingContext: buildGroundingContext(evidence),
      hasAuthoritativeEvidence: evidence.authoritative.length > 0,
    });
    return this.buildTriageResponse(result, evidence);
  }

  private async runNativeTriage(request: TriageRequest): Promise<TriageResponse> {
    return this.invokeNativeModel('triage', request);
  }

  private buildVisualAssistRequest(request: TriageRequest): TriageRequest {
    const trimmedUserText = request.userText.trim();

    return {
      ...request,
      categoryHint: request.categoryHint ?? VISUAL_ASSIST_CATEGORY,
      imageBase64: request.imageBase64,
      userText:
        trimmedUserText ||
        (request.imageBase64
          ? VISUAL_ASSIST_PROMPT_WITH_IMAGE
          : VISUAL_ASSIST_PROMPT_WITHOUT_IMAGE),
    };
  }

  async triage(request: TriageRequest): Promise<TriageResponse> {
    this.lastLocale = normalizeLocale(request.locale);
    return this.runNativeTriage(request);
  }

  async cancelActiveInference(): Promise<void> {
    await NativeBeacon.cancelActiveInference();
  }

  async *triageStream(request: TriageRequest): AsyncIterable<StreamChunk> {
    this.lastLocale = normalizeLocale(request.locale);
    await safeImpact(ImpactStyle.Light);
    await warmKnowledgeEngine();

    const evidence = retrieveEvidenceBundle(request);
    const streamId = createStreamId();
    const queue: Array<{
      streamId: string;
      delta?: string;
      done?: boolean;
      error?: string;
      finalText?: string;
      usedProfileName?: string;
    }> = [];
    let completed = false;
    let failure: Error | null = null;
    let streamedText = '';

    const listener = await NativeBeacon.addListener('triageStreamEvent', (event) => {
      if (event.streamId !== streamId) {
        return;
      }
      queue.push(event);
      if (event.done) {
        completed = true;
      }
    });

    try {
      await NativeBeacon.triageStream({
        modelId: this.getActiveModelId(),
        streamId,
        userText: request.userText,
        categoryHint: request.categoryHint,
        powerMode: request.powerMode,
        imageBase64: request.imageBase64,
        locale: request.locale,
        sessionId: request.sessionId,
        resetContext: request.resetContext,
        groundingContext: buildGroundingContext(evidence),
        hasAuthoritativeEvidence: evidence.authoritative.length > 0,
      });

      while (!completed || queue.length > 0) {
        while (queue.length > 0) {
          const next = queue.shift();
          if (!next) {
            continue;
          }

          if (next.delta) {
            streamedText += next.delta;
            yield { delta: next.delta };
          }

          if (next.done) {
            completed = true;
            if (next.error) {
              failure = new Error(next.error);
              continue;
            }

            const finalText = next.finalText ?? streamedText;
            if (!hasMeaningfulModelText(finalText)) {
              failure = new Error(translateMessage(this.lastLocale, 'status.infer_failed'));
              continue;
            }

            yield {
              delta: '',
              done: true,
              final: this.buildTriageResponse(
                {
                  text: finalText,
                  usedProfileName: next.usedProfileName,
                },
                evidence,
              ),
            };
          }
        }

        if (!completed) {
          await new Promise((resolve) => setTimeout(resolve, 16));
        }
      }
    } finally {
      await listener.remove();
    }

    if (failure) {
      throw failure;
    }
  }

  async analyzeVisual(request: TriageRequest): Promise<TriageResponse> {
    this.lastLocale = normalizeLocale(request.locale);
    await safeImpact(ImpactStyle.Light);
    return this.invokeNativeModel('visual', this.buildVisualAssistRequest(request));
  }

  async toggleSos(request: SosRequest): Promise<SosState> {
    this.lastLocale = normalizeLocale(request.locale);
    const next = estimateSosState(request.summary, !this.sosState.active);
    this.sosState = next;

    const [position, networkStatus] = await Promise.all([
      Geolocation.getCurrentPosition({
        enableHighAccuracy: false,
        maximumAge: 60_000,
        timeout: 8_000,
      }).catch(() => null),
      Network.getStatus().catch(() => null),
    ]);

    await writeJson(STORAGE_KEYS.sosState, this.sosState);
    await writeJson(STORAGE_KEYS.lastSosPacket, {
      summary: request.summary,
      locale: this.lastLocale,
      location: position
        ? {
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            accuracy: position.coords.accuracy,
          }
        : null,
      networkConnected: networkStatus?.connected ?? false,
      updatedAt: new Date().toISOString(),
    });

    await safeImpact(next.active ? ImpactStyle.Heavy : ImpactStyle.Medium);
    return this.sosState;
  }

  async getBatteryStatus(): Promise<BatteryStatus> {
    const battery = await Device.getBatteryInfo().catch(() => null);
    const levelRaw = battery?.batteryLevel;
    const level =
      typeof levelRaw === 'number' && !Number.isNaN(levelRaw)
        ? levelRaw > 1
          ? levelRaw / 100
          : levelRaw
        : this.powerMode === 'doomsday'
          ? 0.08
          : 0.42;

    const isLowPowerMode =
      battery?.isCharging === false && (level < 0.1 || this.powerMode === 'doomsday');

    return {
      level,
      isLowPowerMode,
      forcedPowerMode: this.powerMode,
      warningCode:
        level < 0.1 || this.powerMode === 'doomsday' ? BATTERY_WARNING_CODE : undefined,
      warning:
        level < 0.1 || this.powerMode === 'doomsday'
          ? localizeBatteryWarning(this.lastLocale)
          : undefined,
    };
  }

  async setPowerMode(mode: PowerMode): Promise<BatteryStatus> {
    this.powerMode = mode;
    await Preferences.set({ key: STORAGE_KEYS.powerMode, value: mode });
    return this.getBatteryStatus();
  }

  async getRuntimeDiagnostics(): Promise<RuntimeDiagnostics> {
    return NativeBeacon.getRuntimeDiagnostics();
  }

  async listModels(): Promise<ModelDescriptor[]> {
    const result = await NativeBeacon.listModels();
    this.models = result.models;
    return this.models.map((model) => ({ ...model }));
  }

  async loadModel(modelId: string): Promise<ModelDescriptor[]> {
    const result = await NativeBeacon.loadModel({ modelId });
    this.models = result.models;
    return this.models.map((model) => ({ ...model }));
  }

  async *downloadModel(modelId: string): AsyncIterable<ModelDownloadProgress> {
    const queue: Array<ModelDownloadProgress & { done?: boolean }> = [];
    let completed = false;
    let failure: Error | null = null;
    const listener = await NativeBeacon.addListener('modelDownloadProgress', (progress) => {
      if (progress.modelId !== modelId) {
        return;
      }
      queue.push(progress);
      if (progress.done) {
        completed = true;
      }
    });

    NativeBeacon.downloadModel({ modelId })
      .then(() => {
        completed = true;
      })
      .catch((error: unknown) => {
        failure = error instanceof Error ? error : new Error(String(error));
        completed = true;
      });

    try {
      while (!completed || queue.length > 0) {
        while (queue.length > 0) {
          const next = queue.shift();
          if (!next) {
            continue;
          }
          yield {
            modelId: next.modelId,
            receivedBytes: next.receivedBytes,
            totalBytes: next.totalBytes,
            fraction: next.fraction,
            isResumed: next.isResumed,
            status: next.status,
            bytesPerSecond: next.bytesPerSecond,
            remainingMs: next.remainingMs,
            errorMessage: next.errorMessage,
          };
        }

        if (!completed) {
          await new Promise((resolve) => setTimeout(resolve, 120));
        }
      }
    } finally {
      await listener.remove();
    }

    if (failure) {
      throw failure;
    }
  }
}

export function createCapacitorBeaconBridge(): BeaconBridge {
  return new CapacitorBeaconBridge();
}
