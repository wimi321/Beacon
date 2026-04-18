import { registerPlugin } from '@capacitor/core';
import type { ModelDescriptor, ModelDownloadProgress, RuntimeDiagnostics } from './types';

export type NativeTriageRequest = {
  modelId?: string;
  streamId?: string;
  userText: string;
  categoryHint?: string;
  powerMode: string;
  imageBase64?: string;
  locale?: string;
  sessionId: string;
  resetContext?: boolean;
  groundingContext?: string;
  hasAuthoritativeEvidence?: boolean;
};

export type NativeTriageResult = {
  text: string;
  modelId: string;
  usedProfileName: string;
};

export type NativeTriageStreamStartResult = {
  streamId: string;
};

export type NativeTriageStreamEvent = {
  streamId: string;
  delta?: string;
  done?: boolean;
  error?: string;
  finalText?: string;
  modelId?: string;
  usedProfileName?: string;
};

export type NativeModelListResult = {
  models: Array<ModelDescriptor & { isDownloaded?: boolean }>;
};

export interface BeaconNativePlugin {
  listModels(): Promise<NativeModelListResult>;
  loadModel(options: { modelId: string }): Promise<NativeModelListResult>;
  downloadModel(options: { modelId: string }): Promise<{ modelId: string; localPath: string; downloaded: boolean }>;
  triage(options: NativeTriageRequest): Promise<NativeTriageResult>;
  triageStream(options: NativeTriageRequest): Promise<NativeTriageStreamStartResult>;
  cancelActiveInference(): Promise<{ cancelled: boolean }>;
  analyzeVisual(options: NativeTriageRequest): Promise<NativeTriageResult>;
  getRuntimeDiagnostics(): Promise<RuntimeDiagnostics>;
  addListener(
    eventName: 'modelDownloadProgress',
    listenerFunc: (progress: ModelDownloadProgress & { done?: boolean }) => void,
  ): Promise<{ remove: () => Promise<void> }>;
  addListener(
    eventName: 'triageStreamEvent',
    listenerFunc: (event: NativeTriageStreamEvent) => void,
  ): Promise<{ remove: () => Promise<void> }>;
}

export const NativeBeacon = registerPlugin<BeaconNativePlugin>('BeaconNative');
