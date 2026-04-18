import '../models/knowledge_models.dart';

abstract interface class KnowledgeStore {
  Future<void> upsertAll(List<KnowledgeEntry> entries);
  Future<List<KnowledgeEntry>> findByCategory({
    required String category,
    required int limit,
  });
  Future<List<RetrievedKnowledge>> search({
    required String query,
    required int limit,
  });
}
