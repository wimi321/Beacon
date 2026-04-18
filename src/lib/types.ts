export type Sender = 'user' | 'ai' | 'system';

export type GuidanceMode = 'grounded';
export type PowerMode = 'normal' | 'doomsday';
export type ModelTier = 'e2b' | 'e4b';
export type BatteryWarningCode = 'battery.low_power_emergency';
export type ModelDownloadStatus =
  | 'not_downloaded'
  | 'partially_downloaded'
  | 'in_progress'
  | 'succeeded'
  | 'failed';

export type CapabilityClass =
  | 'supported'
  | 'unsupported_memory'
  | 'runtime_unstable'
  | 'simulator'
  | 'unknown';

export type SupportedDeviceClass =
  | 'iphone_primary'
  | 'iphone_legacy'
  | 'ipad_compat'
  | 'ipad_low_memory'
  | 'simulator'
  | 'unknown';

export type RuntimeStack = 'litert-lm-c-api' | 'litert-lm-swift-sdk' | 'unknown';
export type ArtifactFormat = 'litertlm' | 'task' | 'unknown';
export type PreferredBackend = 'auto-real' | 'gpu' | 'cpu' | 'unknown';

export type RetrievedKnowledge = {
  id: string;
  sourceId: string;
  title: string;
  source: string;
  summary: string;
  steps: string[];
  contraindications: string[];
  escalation: string;
  strategy: 'directRule' | 'lexical';
  score: number;
};

export type EvidenceBundle = {
  authoritative: RetrievedKnowledge[];
  supporting: RetrievedKnowledge[];
  matchedCategories: string[];
  queryTerms: string[];
};

export type TriageRequest = {
  userText: string;
  categoryHint?: string;
  powerMode: PowerMode;
  imageBase64?: string;
  locale?: string;
  sessionId: string;
  resetContext?: boolean;
};

export type SosRequest = {
  summary: string;
  locale?: string;
};

export type TriageResponse = {
  summary: string;
  steps: string[];
  disclaimer: string;
  isKnowledgeBacked: boolean;
  guidanceMode: GuidanceMode;
  evidence: EvidenceBundle;
  usedProfileName: string;
};

export type SosState = {
  active: boolean;
  connectedPeers: number;
  lastBroadcastAt?: string;
};

export type BatteryStatus = {
  level: number;
  isLowPowerMode: boolean;
  forcedPowerMode: PowerMode;
  warningCode?: BatteryWarningCode;
  warning?: string;
};

export type RuntimeBenchmark = {
  totalInitMs?: number;
  timeToFirstTokenMs?: number;
  lastPrefillTokenCount?: number;
  lastDecodeTokenCount?: number;
  lastPrefillTokensPerSecond?: number;
  lastDecodeTokensPerSecond?: number;
};

export type RuntimeBundleAudit = {
  gpuEnvironmentSymbolPresent?: boolean;
  metalTensorInteropSymbolPresent?: boolean;
  metalArgumentBufferSymbolPresent?: boolean;
  staticTopKMetalSamplerSymbolPresent?: boolean;
  topKMetalSamplerDylibPresent?: boolean;
  metalAcceleratorDylibPresent?: boolean;
  runtimeLibraryDir?: string;
  expectedMetalAcceleratorPath?: string;
  expectedMetalAcceleratorExists?: boolean;
  expectedMetalAcceleratorLoadable?: boolean;
  expectedMetalAcceleratorLoadError?: string;
  gpuSymbolsPresent?: boolean;
  metalSamplerPresent?: boolean;
};

export type RuntimeDiagnostics = {
  platform: 'ios' | 'android' | 'web';
  loadedModelId?: string;
  isLoaded: boolean;
  activeBackend: string;
  activeVisionBackend?: string;
  acceleratorFamily: 'metal' | 'gpu' | 'cpu' | 'unknown';
  lastEngineAttempt?: string;
  lastEngineFailure?: string;
  engineAttemptLog?: string[];
  gpuAttempted?: boolean;
  gpuFallbackToCpu?: boolean;
  gpuFailureDetail?: string;
  bundleAudit?: RuntimeBundleAudit;
  benchmark?: RuntimeBenchmark;
  simulator?: boolean;
  metalAvailable?: boolean;
  metalDeviceName?: string;
  physicalMemoryBytes?: number;
  minimumRecommendedMemoryBytes?: number;
  runtimeStack?: RuntimeStack;
  artifactFormat?: ArtifactFormat;
  capabilityClass?: CapabilityClass;
  gpuEligible?: boolean;
  gpuWarmupPassed?: boolean;
  gpuWarmupAttempted?: boolean;
  gpuBlockedReason?: string;
  supportedDeviceClass?: SupportedDeviceClass;
  preferredBackend?: PreferredBackend;
};

export type ModelDescriptor = {
  id: string;
  tier: ModelTier;
  name: string;
  localPath: string;
  sizeLabel: string;
  isLoaded: boolean;
  isBundled?: boolean;
  isDownloaded?: boolean;
  sizeBytes?: number;
  defaultProfileName?: string | null;
  recommendedFor?: string | null;
  supportsImageInput?: boolean;
  acceleratorHints?: string[];
  activeBackend?: string;
  activeVisionBackend?: string;
  acceleratorFamily?: RuntimeDiagnostics['acceleratorFamily'];
  downloadStatus?: ModelDownloadStatus;
  artifactFormat?: ArtifactFormat;
  runtimeStack?: RuntimeStack;
  minCapabilityClass?: string;
  preferredBackend?: PreferredBackend;
  supportsVision?: boolean;
  capabilityClass?: CapabilityClass;
  supportedDeviceClass?: SupportedDeviceClass;
};

export type ModelDownloadProgress = {
  modelId: string;
  receivedBytes: number;
  totalBytes: number;
  fraction: number;
  isResumed: boolean;
  status: ModelDownloadStatus;
  bytesPerSecond?: number;
  remainingMs?: number;
  errorMessage?: string;
};

export type BeaconMessage = {
  id: string;
  sender: Sender;
  text: string;
  isStreaming?: boolean;
  isAuthoritative?: boolean;
  guidanceMode?: GuidanceMode;
  evidence?: EvidenceBundle;
  disclaimer?: string;
};
