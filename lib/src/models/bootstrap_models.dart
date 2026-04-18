import 'knowledge_models.dart';
import 'model_models.dart';
import '../generated/generated_knowledge.dart';

class BootstrapModels {
  const BootstrapModels._();

  static const gemma4E2b = ModelDescriptor(
    id: 'gemma-4-e2b',
    tier: ModelTier.e2b,
    localPath: 'models/gemma-4-e2b.litertlm',
    isMultimodal: true,
    sizeBytes: 0,
    sha256: '',
  );

  static const gemma4E4b = ModelDescriptor(
    id: 'gemma-4-e4b',
    tier: ModelTier.e4b,
    localPath: 'models/gemma-4-e4b.litertlm',
    isMultimodal: true,
    sizeBytes: 0,
    sha256: '',
  );

  static List<KnowledgeEntry> emergencySeedKnowledge() {
    return List<KnowledgeEntry>.unmodifiable(generatedKnowledgeEntries);
  }
}
