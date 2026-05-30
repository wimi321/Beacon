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
const VISUAL_ASSIST_PROMPT = '你看见了什么';
const VISUAL_IMAGE_REQUIRED_ERROR = 'No image provided for visual analysis.';

function normalizeLocale(locale?: string): string {
  return locale?.trim() || 'en';
}

function localizeBatteryWarning(locale: string): string {
  return translateMessage(locale, 'warning.battery_low');
}

function isVisualAssistRequest(request: TriageRequest): boolean {
  return request.categoryHint === translateMessage('en', 'action.visual_help') || request.categoryHint === 'visual_help';
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

  private buildVisualAssistRequest(request: TriageRequest): TriageRequest {
    const imageBase64 = request.imageBase64?.trim();
    const imageUri = request.imageUri?.trim();
    if (!imageBase64 && !imageUri) {
      throw new Error(VISUAL_IMAGE_REQUIRED_ERROR);
    }

    return {
      ...request,
      imageBase64,
      imageUri,
      userText: request.userText.trim() || VISUAL_ASSIST_PROMPT,
      categoryHint: request.categoryHint ?? translateMessage(this.lastLocale, 'action.visual_help'),
    };
  }

  async *triageStream(request: TriageRequest): AsyncIterable<StreamChunk> {
    this.lastLocale = normalizeLocale(request.locale);
    const streamRequest = request.imageBase64 || request.imageUri || isVisualAssistRequest(request)
      ? this.buildVisualAssistRequest(request)
      : request;
    await warmKnowledgeEngine();
    const response = inferTriageResponse(streamRequest);
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
    return inferTriageResponse(this.buildVisualAssistRequest(request));
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
      visionArtifactValid: true,
      visionArtifactReason: 'Mock runtime accepts image payloads.',
      visionArtifactContract: 'mock',
      visionInputMode: 'imageUri',
      visionEncoderSignature: 'mock',
      foundVisionSignatures: ['mock'],
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
