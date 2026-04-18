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

export type StreamChunk = {
  delta: string;
  done?: boolean;
  final?: TriageResponse;
};

export interface BeaconBridge {
  initialize(): Promise<void>;
  triage(request: TriageRequest): Promise<TriageResponse>;
  triageStream(request: TriageRequest): AsyncIterable<StreamChunk>;
  cancelActiveInference(): Promise<void>;
  analyzeVisual(request: TriageRequest): Promise<TriageResponse>;
  toggleSos(request: SosRequest): Promise<SosState>;
  getBatteryStatus(): Promise<BatteryStatus>;
  setPowerMode(mode: PowerMode): Promise<BatteryStatus>;
  getRuntimeDiagnostics(): Promise<RuntimeDiagnostics>;
  listModels(): Promise<ModelDescriptor[]>;
  loadModel(modelId: string): Promise<ModelDescriptor[]>;
  downloadModel(modelId: string): AsyncIterable<ModelDownloadProgress>;
}

declare global {
  interface Window {
    beaconBridge?: BeaconBridge;
  }
}
