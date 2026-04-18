import 'dart:math';

import '../contracts/knowledge_store.dart';
import '../models/knowledge_models.dart';

final List<({RegExp pattern, List<String> variants})> _semanticQueryRules = [
  (
    pattern: RegExp(r'迷路|失联|失聯|找不到路|没信号|沒有信號|lost|stranded|disconnected',
        caseSensitive: false),
    variants: <String>[
      'lost',
      'stranded',
      'survival field',
      'signaling for rescue'
    ],
  ),
  (
    pattern: RegExp(r'庇护|庇護|避难|避難|过夜|過夜|shelter|bivouac|camp overnight',
        caseSensitive: false),
    variants: <String>['shelter', 'survival field', 'emergency shelter'],
  ),
  (
    pattern: RegExp(r'取火|生火|火种|火種|fire-starting|build a fire|start a fire',
        caseSensitive: false),
    variants: <String>['fire-starting', 'build a fire', 'warming shelter'],
  ),
  (
    pattern: RegExp(
        r'净水|淨水|溪水|喝生水|喝溪水|water purification|treat water|boil water',
        caseSensitive: false),
    variants: <String>[
      'water purification',
      'treat water',
      'boil water',
      'drinking water safety'
    ],
  ),
  (
    pattern: RegExp(r'路线|路線|留行程|行程计划|行程計劃|trip plan|route plan|ten essentials',
        caseSensitive: false),
    variants: <String>[
      'trip plan',
      'route plan',
      'ten essentials',
      'outdoor emergency plan'
    ],
  ),
  (
    pattern: RegExp(
        r'求救信号|求救訊號|信号弹|信號彈|镜面反光|signaling|rescue signal|emergency signal',
        caseSensitive: false),
    variants: <String>['signaling', 'rescue signal', 'emergency signal'],
  ),
  (
    pattern: RegExp(r'一氧化碳|煤气中毒|煤煙|carbon monoxide|co poisoning',
        caseSensitive: false),
    variants: <String>['carbon monoxide', 'co poisoning'],
  ),
  (
    pattern: RegExp(
        r'胸痛|胸口痛|胸口很痛|胸闷|胸悶|心口痛|心脏痛|心臟痛|左臂痛|冒冷汗|heart attack|chest pain|myocardial infarction',
        caseSensitive: false),
    variants: <String>['heart attack', 'chest pain', 'myocardial infarction'],
  ),
  (
    pattern: RegExp(
        r'烧伤|燒傷|烫伤|燙傷|热油烫|熱油燙|火烧伤|burns?|scald|thermal burn',
        caseSensitive: false),
    variants: <String>['burn', 'burns', 'scald', 'thermal burn'],
  ),
  (
    pattern: RegExp(r'中风|脑卒中|卒中|stroke|fast', caseSensitive: false),
    variants: <String>[
      'stroke',
      'face drooping',
      'arm weakness',
      'speech trouble'
    ],
  ),
  (
    pattern: RegExp(r'脑震荡|颅脑损伤|头部外伤|头部撞击|concussion|tbi|traumatic brain injury',
        caseSensitive: false),
    variants: <String>['concussion', 'traumatic brain injury', 'head trauma'],
  ),
  (
    pattern: RegExp(r'蛇咬|毒蛇|snake bite|snakebite', caseSensitive: false),
    variants: <String>['snake bite', 'snakebite', 'venomous snakes'],
  ),
  (
    pattern:
        RegExp(r'阿片|阿片类|纳洛酮|过量|opioid|overdose|naloxone', caseSensitive: false),
    variants: <String>['opioid', 'overdose', 'naloxone'],
  ),
  (
    pattern: RegExp(r'食物中毒|food poisoning', caseSensitive: false),
    variants: <String>['food poisoning', 'staphylococcal food poisoning'],
  ),
  (
    pattern: RegExp(r'中暑|热射病|热衰竭|高温|heat stroke|heat exhaustion|heat stress',
        caseSensitive: false),
    variants: <String>['heat stroke', 'heat stress', 'extreme heat'],
  ),
  (
    pattern: RegExp(r'冻伤|低体温|失温|frostbite|hypothermia', caseSensitive: false),
    variants: <String>['frostbite', 'hypothermia'],
  ),
  (
    pattern: RegExp(r'雷击|雷暴|打雷|lightning|thunderstorm', caseSensitive: false),
    variants: <String>['lightning', 'thunderstorm safety'],
  ),
  (
    pattern: RegExp(r'植物中毒|毒草|毒植物|poisonous plants?', caseSensitive: false),
    variants: <String>['poisonous plants'],
  ),
  (
    pattern: RegExp(r'蜱虫|tick bite|ticks', caseSensitive: false),
    variants: <String>['ticks', 'tick bite'],
  ),
  (
    pattern: RegExp(r'洪水|内涝|flood', caseSensitive: false),
    variants: <String>['floods', 'storms and floods'],
  ),
  (
    pattern: RegExp(r'触电|电击|electric shock|electrical', caseSensitive: false),
    variants: <String>['electric shock', 'electrical safety'],
  ),
  (
    pattern: RegExp(
        r'战争|戰爭|炮击|炮擊|轰炸|轟炸|爆炸|枪击|槍擊|active shooter|blast|explosion|war zone',
        caseSensitive: false),
    variants: <String>[
      'explosion safety',
      'hard cover',
      'shelter in place',
      'crisis conflict'
    ],
  ),
  (
    pattern: RegExp(
        r'核战|核戰|核爆|辐射|輻射|脏弹|髒彈|dirty bomb|radiation|nuclear|fallout|radiological',
        caseSensitive: false),
    variants: <String>[
      'radiation emergency',
      'nuclear emergency',
      'fallout',
      'dirty bomb'
    ],
  ),
  (
    pattern: RegExp(
        r'病毒袭击|病毒攻擊|生物袭击|生物攻擊|疫情|大流行|anthrax|biohazard|biological attack|pandemic|outbreak',
        caseSensitive: false),
    variants: <String>['biohazard', 'biological attack', 'pandemic', 'anthrax'],
  ),
  (
    pattern: RegExp(
        r'ai攻击|ai攻擊|网络攻击|網絡攻擊|网络入侵|網絡入侵|cyberattack|cyber attack|ransomware|power outage|通信中断|通訊中斷',
        caseSensitive: false),
    variants: <String>[
      'cyberattack',
      'communications outage',
      'power outage',
      'infrastructure failure'
    ],
  ),
];

bool _isOutdoorSurvivalQuery(String query) {
  return RegExp(
    r'野外|徒步|登山|露营|露營|迷路|失联|失聯|没信号|沒有信號|求救|过夜|過夜|庇护|庇護|取火|生火|净水|淨水|溪水|打雷|雷暴|雷击|雷擊|山洪|暴雨|失温|失溫|冻伤|凍傷|中暑|蜱虫|蜱蟲|毒植物|蛇咬|蜘蛛咬|trip plan|ten essentials|wilderness|lost|stranded|shelter|water purification|lightning|hypothermia',
    caseSensitive: false,
  ).hasMatch(query);
}

bool _isChestPainQuery(String query) {
  return RegExp(
    r'胸痛|胸口痛|胸口很痛|胸闷|胸悶|心口痛|心脏痛|心臟痛|左臂痛|冒冷汗|heart attack|chest pain|myocardial infarction',
    caseSensitive: false,
  ).hasMatch(query);
}

bool _isBurnQuery(String query) {
  return RegExp(
    r'烧伤|燒傷|烫伤|燙傷|热油烫|熱油燙|火烧伤|burns?|scald|thermal burn',
    caseSensitive: false,
  ).hasMatch(query);
}

bool _isRadiationQuery(String query) {
  return RegExp(
    r'核战|核戰|核爆|辐射|輻射|脏弹|髒彈|dirty bomb|radiation|nuclear|fallout|radiological',
    caseSensitive: false,
  ).hasMatch(query);
}

bool _isBioQuery(String query) {
  return RegExp(
    r'病毒袭击|病毒攻擊|生物袭击|生物攻擊|疫情|大流行|anthrax|biohazard|biological attack|pandemic|outbreak|隔离|隔離|传染|傳染',
    caseSensitive: false,
  ).hasMatch(query);
}

bool _isCyberQuery(String query) {
  return RegExp(
    r'ai攻击|ai攻擊|网络攻击|網絡攻擊|网络入侵|網絡入侵|cyberattack|cyber attack|ransomware|power outage|停电|停電|通信中断|通訊中斷|断网|斷網|infrastructure failure',
    caseSensitive: false,
  ).hasMatch(query);
}

bool _isConflictQuery(String query) {
  return RegExp(
    r'战争|戰爭|炮击|炮擊|轰炸|轟炸|爆炸|枪击|槍擊|空袭|空襲|war zone|blast|explosion|active shooter',
    caseSensitive: false,
  ).hasMatch(query);
}

String _entrySourceText(KnowledgeEntry entry) {
  return <String>[
    entry.source,
    entry.sourceUrl,
    ...entry.tags,
    ...entry.aliases,
    entry.title,
    entry.summary,
  ].join(' ').toLowerCase();
}

double _sourceIntentBoost(KnowledgeEntry entry, String query) {
  final sourceText = _entrySourceText(entry);
  var boost = 0.0;

  if (_isOutdoorSurvivalQuery(query)) {
    if (RegExp(r'national park service|nps\.gov|weather\.gov|noaa|ready\.gov|cdc',
                caseSensitive: false)
            .hasMatch(sourceText) &&
        RegExp(
          r'survival_|outdoor|trip plan|ten essentials|wilderness|lightning|flood|heat|hypothermia|tick|poisonous plants|venomous snakes|venomous spiders',
          caseSensitive: false,
        ).hasMatch(sourceText)) {
      boost += 26;
    }

    if (RegExp(r'fm 21-76|us army', caseSensitive: false)
            .hasMatch(sourceText) &&
        !RegExp(r'战争|戰爭|war|combat|军事|軍事|核战|核戰', caseSensitive: false)
            .hasMatch(query)) {
      boost -= 10;
    }

    if (RegExp(r'msd manual|merck manual|medlineplus|nhs', caseSensitive: false)
            .hasMatch(sourceText) &&
        RegExp(
          r'野外|徒步|露营|露營|登山|迷路|断联|斷聯|没信号|沒有信號|庇护|庇護|取火|净水|淨水|天黑|求救|路线|路線|雷击|雷擊|雷暴|山洪|过夜|過夜',
          caseSensitive: false,
        ).hasMatch(query) &&
        !RegExp(
          r'蛇咬|蜘蛛|蜱虫|蜱蟲|毒植物|中暑|热射病|熱射病|失温|失溫|冻伤|凍傷|中毒|腹泻|腹瀉|呕吐|嘔吐|烧伤|燒傷|外伤|外傷|骨折',
          caseSensitive: false,
        ).hasMatch(query)) {
      boost -= 8;
    }
  }

  if (_isChestPainQuery(query) &&
      RegExp(
        r'heart attack|myocardial infarction|acute coronary|cardiac|coronary|chest pain|胸痛|心梗|压榨痛',
        caseSensitive: false,
      ).hasMatch(sourceText)) {
    boost += 34;
  }

  if (_isBurnQuery(query)) {
    if (RegExp(
      r'burn|burns|scald|thermal burn|烧伤|燒傷|烫伤|燙傷',
      caseSensitive: false,
    ).hasMatch(sourceText)) {
      boost += 30;
    }

    if (RegExp(r'fm 21-76|us army', caseSensitive: false)
        .hasMatch(sourceText)) {
      boost -= 12;
    }
  }

  if (_isRadiationQuery(query) &&
      RegExp(
        r'crisis_radiation|radiation|nuclear|radiological|fallout|dirty bomb|ready\.gov|cdc',
        caseSensitive: false,
      ).hasMatch(sourceText)) {
    boost += 30;
  }

  if (_isBioQuery(query) &&
      RegExp(
        r'crisis_bio|biohazard|pandemic|anthrax|hazmat|ready\.gov|cdc',
        caseSensitive: false,
      ).hasMatch(sourceText)) {
    boost += 26;
  }

  if (_isCyberQuery(query) &&
      RegExp(
        r'crisis_cyber|cyber|power outage|communications outage|get-tech-ready|infrastructure failure|ready\.gov|cisa',
        caseSensitive: false,
      ).hasMatch(sourceText)) {
    boost += 28;
  }

  if (_isConflictQuery(query) &&
      RegExp(
        r'crisis_conflict|explosion|hard cover|shelter in place|public-spaces|ready\.gov|radiation',
        caseSensitive: false,
      ).hasMatch(sourceText)) {
    boost += 24;
  }

  return boost;
}

class InMemoryKnowledgeStore implements KnowledgeStore {
  final Map<String, KnowledgeEntry> _entries = <String, KnowledgeEntry>{};

  @override
  Future<void> upsertAll(List<KnowledgeEntry> entries) async {
    for (final entry in entries) {
      _entries[entry.id] = entry;
    }
  }

  @override
  Future<List<KnowledgeEntry>> findByCategory({
    required String category,
    required int limit,
  }) async {
    final normalizedCategory = category.trim().toLowerCase();
    if (normalizedCategory.isEmpty) {
      return const <KnowledgeEntry>[];
    }

    final matched = _entries.values.where((entry) {
      final candidates = <String>[
        entry.title,
        ...entry.tags,
        ...entry.aliases,
      ].map((value) => value.toLowerCase());

      return candidates.any(
        (candidate) =>
            candidate.contains(normalizedCategory) ||
            normalizedCategory.contains(candidate),
      );
    }).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));

    return matched.take(limit).toList(growable: false);
  }

  @override
  Future<List<RetrievedKnowledge>> search({
    required String query,
    required int limit,
  }) async {
    final normalizedQuery = query.toLowerCase().trim();
    final normalizedTerms = _tokenize(normalizedQuery);
    if (normalizedTerms.isEmpty) {
      return const <RetrievedKnowledge>[];
    }

    final totalEntries = _entries.length;
    final scored = _entries.values
        .map((entry) =>
            _scoreEntry(entry, normalizedQuery, normalizedTerms, totalEntries))
        .where((result) => result != null)
        .cast<RetrievedKnowledge>()
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    return scored.take(limit).toList(growable: false);
  }

  RetrievedKnowledge? _scoreEntry(
    KnowledgeEntry entry,
    String normalizedQuery,
    List<String> queryTerms,
    int totalEntries,
  ) {
    final documentTerms = _tokenize(entry.searchableText);
    if (documentTerms.isEmpty) {
      return null;
    }

    final termFrequency = <String, int>{};
    for (final term in documentTerms) {
      termFrequency.update(term, (value) => value + 1, ifAbsent: () => 1);
    }

    final uniqueQueryTerms = queryTerms.toSet().toList(growable: false);
    final matchedTerms = <String>[];
    var lexicalScore = 0.0;

    for (final term in uniqueQueryTerms) {
      final frequency = termFrequency[term];
      if (frequency == null) {
        continue;
      }

      matchedTerms.add(term);
      final docsWithTerm = _entries.values
          .where(
            (candidate) => candidate.searchableText.contains(term),
          )
          .length;
      final inverseDocumentFrequency =
          log(((totalEntries - docsWithTerm) + 0.5) / (docsWithTerm + 0.5) + 1);
      final normalizedFrequency =
          frequency / (0.5 + 1.5 * documentTerms.length / 32);

      lexicalScore += inverseDocumentFrequency * normalizedFrequency;
    }

    if (matchedTerms.isEmpty) {
      return null;
    }

    final weightedScore = lexicalScore +
        entry.priority / 8 +
        _sourceIntentBoost(entry, normalizedQuery);
    return RetrievedKnowledge(
      entry: entry,
      score: min(100, weightedScore),
      isAuthoritative: entry.priority >= 8,
      strategy: RetrievalStrategy.lexical,
      matchedTerms: matchedTerms,
    );
  }

  List<String> _tokenize(String input) {
    final normalized = input.toLowerCase().trim();
    if (normalized.isEmpty) {
      return const <String>[];
    }

    final variants = _buildQueryVariants(normalized);
    final coarseTokens = <String>[];
    final cjkBigrams = <String>[];

    for (final variant in variants) {
      coarseTokens.addAll(
        variant
            .split(RegExp(r'[^a-z0-9一-龿]+'))
            .where((token) => token.isNotEmpty),
      );

      final compact = variant.replaceAll(RegExp(r'\s+'), '');
      for (var index = 0; index < compact.length - 1; index++) {
        final pair = compact.substring(index, index + 2);
        if (RegExp(r'[一-龿]').hasMatch(pair)) {
          cjkBigrams.add(pair);
        }
      }
    }

    return <String>{...variants, ...coarseTokens, ...cjkBigrams}
        .toList(growable: false);
  }

  List<String> _buildQueryVariants(String normalized) {
    final variants = <String>{normalized};
    for (final rule in _semanticQueryRules) {
      if (rule.pattern.hasMatch(normalized)) {
        variants.addAll(rule.variants.map((variant) => variant.toLowerCase()));
      }
    }
    return variants.toList(growable: false);
  }
}
