import '../src/contracts/knowledge_store.dart';
import '../src/models/knowledge_models.dart';
import '../src/models/bootstrap_models.dart';
import '../src/storage/in_memory_knowledge_store.dart';

class IsarKnowledgeStore implements KnowledgeStore {
  IsarKnowledgeStore({bool preloadSeedKnowledge = true}) {
    if (preloadSeedKnowledge) {
      _delegate.upsertAll(BootstrapModels.emergencySeedKnowledge());
    }
  }

  final InMemoryKnowledgeStore _delegate = InMemoryKnowledgeStore();

  @override
  Future<List<KnowledgeEntry>> findByCategory({
    required String category,
    required int limit,
  }) => _delegate.findByCategory(category: category, limit: limit);

  @override
  Future<List<RetrievedKnowledge>> search({
    required String query,
    required int limit,
  }) => _delegate.search(query: query, limit: limit);

  @override
  Future<void> upsertAll(List<KnowledgeEntry> entries) => _delegate.upsertAll(entries);
}
