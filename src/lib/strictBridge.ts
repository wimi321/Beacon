import type {
  BatteryStatus,
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

const LOCAL_MODEL_ERROR =
  'Native local model runtime is not connected. Beacon refuses to answer without a real on-device model bridge.';

export class LocalModelUnavailableError extends Error {
  constructor(message: string = LOCAL_MODEL_ERROR) {
    super(message);
    this.name = 'LocalModelUnavailableError';
  }
}

export function createStrictLocalModelBridge(): BeaconBridge {
  return {
    async initialize(): Promise<void> {},
    async triage(_request: TriageRequest): Promise<TriageResponse> {
      throw new LocalModelUnavailableError();
    },
    async *triageStream(_request: TriageRequest): AsyncIterable<StreamChunk> {
      throw new LocalModelUnavailableError();
    },
    async cancelActiveInference(): Promise<void> {},
    async analyzeVisual(_request: TriageRequest): Promise<TriageResponse> {
      throw new LocalModelUnavailableError();
    },
    async toggleSos(_request: SosRequest): Promise<SosState> {
      throw new LocalModelUnavailableError(
        'Native incident summarization bridge is not connected. Beacon refuses to fabricate SOS AI output.',
      );
    },
    async getBatteryStatus(): Promise<BatteryStatus> {
      return {
        level: 0,
        isLowPowerMode: false,
        forcedPowerMode: 'normal',
      };
    },
    async setPowerMode(mode: PowerMode): Promise<BatteryStatus> {
      return {
        level: 0,
        isLowPowerMode: mode === 'doomsday',
        forcedPowerMode: mode,
      };
    },
    async getRuntimeDiagnostics(): Promise<RuntimeDiagnostics> {
      return {
        platform: 'web',
        isLoaded: false,
        activeBackend: 'unavailable',
        acceleratorFamily: 'unknown',
        lastEngineFailure: LOCAL_MODEL_ERROR,
        runtimeStack: 'unknown',
        artifactFormat: 'unknown',
        capabilityClass: 'unknown',
        gpuEligible: false,
        gpuWarmupPassed: false,
        gpuWarmupAttempted: false,
        gpuBlockedReason: LOCAL_MODEL_ERROR,
        supportedDeviceClass: 'unknown',
        preferredBackend: 'unknown',
      };
    },
    async listModels(): Promise<ModelDescriptor[]> {
      return [];
    },
    async loadModel(_modelId: string): Promise<ModelDescriptor[]> {
      throw new LocalModelUnavailableError(
        'Native local model loader is not connected. Beacon refuses to fake model state.',
      );
    },
    async *downloadModel(_modelId: string): AsyncIterable<ModelDownloadProgress> {
      throw new LocalModelUnavailableError(
        'Native local model downloader is not connected. Beacon refuses to fake model downloads.',
      );
    },
  };
}
