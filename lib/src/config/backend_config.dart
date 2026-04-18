import '../models/model_models.dart';

class BeaconBackendConfig {
  const BeaconBackendConfig({
    required this.defaultProfile,
    required this.maxRetrievedKnowledge,
    required this.maxAuthoritativeKnowledge,
    required this.lexicalScoreFloor,
    required this.defaultMeshHopLimit,
    required this.defaultMeshTtl,
  });

  final ModelProfile defaultProfile;
  final int maxRetrievedKnowledge;
  final int maxAuthoritativeKnowledge;
  final double lexicalScoreFloor;
  final int defaultMeshHopLimit;
  final Duration defaultMeshTtl;

  factory BeaconBackendConfig.doomsdayDefaults() {
    return BeaconBackendConfig(
      defaultProfile: ModelProfile.e2bBalanced,
      maxRetrievedKnowledge: 6,
      maxAuthoritativeKnowledge: 3,
      lexicalScoreFloor: 1.2,
      defaultMeshHopLimit: 3,
      defaultMeshTtl: const Duration(minutes: 20),
    );
  }
}
