import type {
  BatteryStatus,
  ModelDescriptor,
  PowerMode,
  RuntimeDiagnostics,
  SosRequest,
  SosState,
  TriageRequest,
  TriageResponse,
} from './types';
import type { BeaconBridge, StreamChunk } from './beaconBridge';
import {
  createDefaultModels,
  estimateSosState,
  inferTriageResponse,
  simulateDownload,
  sleep,
  splitStreamingTokens,
  warmKnowledgeEngine,
} from './beaconEngine';
import { translateMessage } from '../i18n/translate';

const BATTERY_WARNING_CODE = 'battery.low_power_emergency' as const;

function normalizeLocale(locale?: string): string {
  return locale?.trim() || 'en';
}

function localizeBatteryWarning(locale: string): string {
  return translateMessage(locale, 'warning.battery_low');
}

class MockBeaconBridge implements BeaconBridge {
  private powerMode: PowerMode = 'normal';
  private sosState: SosState = { active: false, connectedPeers: 0 };
  private models: ModelDescriptor[] = createDefaultModels();
  private lastLocale = 'en';

  async initialize(): Promise<void> {
    await warmKnowledgeEngine();
    await sleep(80);
  }

  async triage(request: TriageRequest): Promise<TriageResponse> {
    this.lastLocale = normalizeLocale(request.locale);
    await warmKnowledgeEngine();
    return inferTriageResponse(request);
  }

  async *triageStream(request: TriageRequest): AsyncIterable<StreamChunk> {
    this.lastLocale = normalizeLocale(request.locale);
    await warmKnowledgeEngine();
    const response = inferTriageResponse(request);
    const tokens = splitStreamingTokens(response);

    for (const token of tokens) {
      await sleep(120);
      yield { delta: token };
    }

    yield { delta: '', done: true, final: response };
  }

  async cancelActiveInference(): Promise<void> {}

  async analyzeVisual(request: TriageRequest): Promise<TriageResponse> {
    this.lastLocale = normalizeLocale(request.locale);
    await warmKnowledgeEngine();
    return inferTriageResponse({
      ...request,
      userText:
        request.userText.trim() ||
        'What dangers do you see and what should I do next?',
      categoryHint: request.categoryHint ?? translateMessage(this.lastLocale, 'action.visual_help'),
    });
  }

  async toggleSos(request: SosRequest): Promise<SosState> {
    this.lastLocale = normalizeLocale(request.locale);
    this.sosState = estimateSosState(request.summary, !this.sosState.active);
    return this.sosState;
  }

  async getBatteryStatus(): Promise<BatteryStatus> {
    const level = this.powerMode === 'doomsday' ? 0.08 : 0.42;
    return {
      level,
      isLowPowerMode: this.powerMode === 'doomsday',
      forcedPowerMode: this.powerMode,
      warningCode: level < 0.1 ? BATTERY_WARNING_CODE : undefined,
      warning:
        level < 0.1
          ? localizeBatteryWarning(this.lastLocale)
          : undefined,
    };
  }

  async setPowerMode(mode: PowerMode): Promise<BatteryStatus> {
    this.powerMode = mode;
    return this.getBatteryStatus();
  }

  async getRuntimeDiagnostics(): Promise<RuntimeDiagnostics> {
    const loadedModel = this.models.find((model) => model.isLoaded);
    return {
      platform: 'web',
      loadedModelId: loadedModel?.id,
      isLoaded: loadedModel !== undefined,
      activeBackend: 'mock',
      activeVisionBackend: 'mock',
      acceleratorFamily: 'unknown',
      runtimeStack: 'unknown',
      artifactFormat: 'litertlm',
      capabilityClass: 'supported',
      gpuEligible: false,
      gpuWarmupPassed: false,
      gpuWarmupAttempted: false,
      gpuBlockedReason: '',
      supportedDeviceClass: 'unknown',
      preferredBackend: 'unknown',
    };
  }

  async listModels(): Promise<ModelDescriptor[]> {
    return [...this.models];
  }

  async loadModel(modelId: string): Promise<ModelDescriptor[]> {
    this.models = this.models.map((model) => ({
      ...model,
      isLoaded: model.id === modelId,
    }));
    return [...this.models];
  }

  async *downloadModel(modelId: string) {
    yield* simulateDownload(modelId);
  }
}

export function createMockBeaconBridge(): BeaconBridge {
  return new MockBeaconBridge();
}
