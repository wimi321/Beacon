enum PowerMode {
  normal,
  doomsday,
}

enum ModelTier {
  e2b,
  e4b,
}

class ModelProfile {
  const ModelProfile({
    required this.name,
    required this.tier,
    required this.maxContextTokens,
    required this.maxResponseTokens,
    required this.maxInferenceSteps,
    required this.preferLowPower,
  });

  final String name;
  final ModelTier tier;
  final int maxContextTokens;
  final int maxResponseTokens;
  final int maxInferenceSteps;
  final bool preferLowPower;

  static const e2bBalanced = ModelProfile(
    name: 'gemma-4-e2b-balanced',
    tier: ModelTier.e2b,
    maxContextTokens: 2048,
    maxResponseTokens: 384,
    maxInferenceSteps: 96,
    preferLowPower: true,
  );

  static const e2bSaver = ModelProfile(
    name: 'gemma-4-e2b-saver',
    tier: ModelTier.e2b,
    maxContextTokens: 1024,
    maxResponseTokens: 256,
    maxInferenceSteps: 48,
    preferLowPower: true,
  );

  static const e4bExpert = ModelProfile(
    name: 'gemma-4-e4b-expert',
    tier: ModelTier.e4b,
    maxContextTokens: 4096,
    maxResponseTokens: 512,
    maxInferenceSteps: 128,
    preferLowPower: false,
  );
}

class ModelDescriptor {
  const ModelDescriptor({
    required this.id,
    required this.tier,
    required this.localPath,
    required this.isMultimodal,
    required this.sizeBytes,
    required this.sha256,
  });

  final String id;
  final ModelTier tier;
  final String localPath;
  final bool isMultimodal;
  final int sizeBytes;
  final String sha256;
}

class DownloadProgress {
  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.isResumed,
  });

  final int receivedBytes;
  final int totalBytes;
  final bool isResumed;

  double get fraction => totalBytes == 0 ? 0 : receivedBytes / totalBytes;
}
