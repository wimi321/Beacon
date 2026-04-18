enum RetrievalStrategy {
  directRule,
  lexical,
}

class KnowledgeEntry {
  const KnowledgeEntry({
    required this.id,
    required this.title,
    required this.summary,
    required this.steps,
    required this.contraindications,
    required this.escalation,
    required this.tags,
    required this.aliases,
    required this.source,
    this.sourceUrl = '',
    required this.priority,
    this.locale = 'zh-CN',
    this.severity = 'critical',
  });

  final String id;
  final String title;
  final String summary;
  final List<String> steps;
  final List<String> contraindications;
  final String escalation;
  final List<String> tags;
  final List<String> aliases;
  final String source;
  final String sourceUrl;
  final int priority;
  final String locale;
  final String severity;

  String get body => [
        summary,
        ...steps,
        if (contraindications.isNotEmpty) '禁忌: ${contraindications.join('；')}',
        '升级就医: $escalation',
      ].join('\n');

  String get searchableText => [
        title,
        summary,
        ...steps,
        ...contraindications,
        escalation,
        ...tags,
        ...aliases,
      ].join(' ').toLowerCase();
}

class RetrievedKnowledge {
  const RetrievedKnowledge({
    required this.entry,
    required this.score,
    required this.isAuthoritative,
    required this.strategy,
    required this.matchedTerms,
  });

  final KnowledgeEntry entry;
  final double score;
  final bool isAuthoritative;
  final RetrievalStrategy strategy;
  final List<String> matchedTerms;
}
