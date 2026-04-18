import 'knowledge_models.dart';

enum GuidanceMode {
  grounded,
}

class EvidenceBundle {
  const EvidenceBundle({
    required this.mode,
    required this.authoritative,
    required this.supporting,
    required this.matchedCategories,
    required this.queryTerms,
  });

  final GuidanceMode mode;
  final List<RetrievedKnowledge> authoritative;
  final List<RetrievedKnowledge> supporting;
  final List<String> matchedCategories;
  final List<String> queryTerms;

  bool get hasAuthoritativeEvidence => authoritative.isNotEmpty;

  List<RetrievedKnowledge> get allEvidence => [
        ...authoritative,
        ...supporting,
      ];
}
