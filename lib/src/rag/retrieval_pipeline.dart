import '../config/backend_config.dart';
import '../contracts/knowledge_store.dart';
import '../models/emergency_models.dart';
import '../models/evidence_models.dart';
import '../models/knowledge_models.dart';

class RetrievalPipeline {
  RetrievalPipeline({
    required KnowledgeStore knowledgeStore,
    required BeaconBackendConfig config,
  })  : _knowledgeStore = knowledgeStore,
        _config = config;

  final KnowledgeStore _knowledgeStore;
  final BeaconBackendConfig _config;

  Future<EvidenceBundle> retrieve(EmergencyRequest request) async {
    final matchedCategories = <String>[];
    final directHits = <RetrievedKnowledge>[];

    if (request.categoryHint != null && request.categoryHint!.trim().isNotEmpty) {
      final category = request.categoryHint!.trim();
      final directEntries = await _knowledgeStore.findByCategory(
        category: category,
        limit: _config.maxAuthoritativeKnowledge,
      );

      if (directEntries.isNotEmpty) {
        matchedCategories.add(category);
        directHits.addAll(
          directEntries.map(
            (entry) => RetrievedKnowledge(
              entry: entry,
              score: 100,
              isAuthoritative: true,
              strategy: RetrievalStrategy.directRule,
              matchedTerms: [category],
            ),
          ),
        );
      }
    }

    final lexicalQuery = [
      request.categoryHint,
      request.userText,
    ].whereType<String>().join(' ');
    final lexicalHits = await _knowledgeStore.search(
      query: lexicalQuery,
      limit: _config.maxRetrievedKnowledge,
    );

    final merged = _mergeEvidence(directHits, lexicalHits);
    final authoritative = merged
        .where(
          (item) =>
              item.isAuthoritative && item.score >= _config.lexicalScoreFloor,
        )
        .take(_config.maxAuthoritativeKnowledge)
        .toList(growable: false);

    final supporting = merged
        .where((item) => !authoritative.any((saved) => saved.entry.id == item.entry.id))
        .take(_config.maxRetrievedKnowledge - authoritative.length)
        .toList(growable: false);

    final queryTerms = _extractTerms(lexicalQuery);
    final mode = GuidanceMode.grounded;

    return EvidenceBundle(
      mode: mode,
      authoritative: authoritative,
      supporting: supporting,
      matchedCategories: matchedCategories,
      queryTerms: queryTerms,
    );
  }

  String buildGroundingContext(EvidenceBundle evidence) {
    if (!evidence.hasAuthoritativeEvidence) {
      return 'NO_AUTHORITATIVE_CONTEXT_FOUND';
    }

    return [
      ...evidence.authoritative.map(
        (item) => [
          'Source: ${item.entry.source}',
          'Title: ${item.entry.title}',
          'Summary: ${item.entry.summary}',
          'Steps:',
          ...item.entry.steps.map((step) => '- $step'),
          if (item.entry.contraindications.isNotEmpty) 'Contraindications:',
          ...item.entry.contraindications.map((item) => '- $item'),
          'Escalation: ${item.entry.escalation}',
        ].join('\n'),
      ),
      ...evidence.supporting.take(2).map(
        (item) => [
          'Supporting source: ${item.entry.source}',
          'Supporting title: ${item.entry.title}',
          'Supporting summary: ${item.entry.summary}',
          'Supporting steps:',
          ...item.entry.steps.take(2).map((step) => '- $step'),
        ].join('\n'),
      ),
    ]
        .join('\n\n---\n\n');
  }

  List<RetrievedKnowledge> _mergeEvidence(
    List<RetrievedKnowledge> directHits,
    List<RetrievedKnowledge> lexicalHits,
  ) {
    final merged = <String, RetrievedKnowledge>{};

    for (final item in [...directHits, ...lexicalHits]) {
      final existing = merged[item.entry.id];
      if (existing == null || existing.score < item.score) {
        merged[item.entry.id] = item;
      }
    }

    final values = merged.values.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return values;
  }

  List<String> _extractTerms(String input) {
    return input
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9一-龿]+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
  }
}
