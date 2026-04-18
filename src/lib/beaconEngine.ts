import type {
  EvidenceBundle,
  ModelDescriptor,
  ModelDownloadProgress,
  PowerMode,
  RetrievedKnowledge,
  SosState,
  TriageRequest,
  TriageResponse,
} from './types';
import {
  ensureKnowledgeBaseLoaded,
  getKnowledgeCards,
  knowledgeCardToRetrieved,
  type KnowledgeCard,
} from './knowledgeBase';
import {
  CANONICAL_SCENARIO_HINTS,
  getScenarioPrimaryCategories,
  getScenarioRetrievalTerms,
  normalizeScenarioHint,
  type CanonicalScenarioHint,
} from './scenarioHints';
import { translateMessage } from '../i18n/translate';

export const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

let cachedKnowledgeCards: KnowledgeCard[] | null = null;
let cachedKnowledgeCardIndex: Map<string, KnowledgeCard> | null = null;

const GROUNDING_MAX_CHARS = 860;
const GROUNDING_SUMMARY_CHARS = 160;
const GROUNDING_STEP_CHARS = 88;
const GROUNDING_ESCALATION_CHARS = 108;

const semanticQueryRules: Array<{ pattern: RegExp; variants: string[] }> = [
  {
    pattern: /(森林|树林|樹林|林子|山林|林区|林區|forest|woods?|woodland|jungle)/i,
    variants: [
      'forest',
      'woods',
      'wilderness',
      'survival field',
      'wilderness travel basics',
      'emergency shelter',
      'signaling for rescue',
    ],
  },
  {
    pattern: /(迷路|失联|失聯|找不到路|没信号|沒有信號|lost|stranded|disconnected)/i,
    variants: ['lost', 'stranded', 'survival field', 'signaling for rescue'],
  },
  {
    pattern: /(庇护|庇護|避难|避難|过夜|過夜|shelter|bivouac|camp overnight)/i,
    variants: ['shelter', 'survival field', 'emergency shelter'],
  },
  {
    pattern: /(取火|生火|火种|火種|fire-starting|build a fire|start a fire)/i,
    variants: ['fire-starting', 'build a fire', 'warming shelter'],
  },
  {
    pattern: /(净水|淨水|溪水|喝生水|喝溪水|water purification|treat water|boil water)/i,
    variants: ['water purification', 'treat water', 'boil water', 'drinking water safety'],
  },
  {
    pattern: /(路线|路線|留行程|行程计划|行程計劃|trip plan|route plan|ten essentials)/i,
    variants: ['trip plan', 'route plan', 'ten essentials', 'outdoor emergency plan'],
  },
  {
    pattern: /(求救信号|求救訊號|信号弹|信號彈|镜面反光|signaling|rescue signal|emergency signal)/i,
    variants: ['signaling', 'rescue signal', 'emergency signal'],
  },
  { pattern: /(一氧化碳|煤气中毒|煤煙|carbon monoxide|co poisoning)/i, variants: ['carbon monoxide', 'co poisoning'] },
  {
    pattern: /(胸痛|胸口痛|胸口很痛|胸闷|胸悶|心口痛|心脏痛|心臟痛|左臂痛|冒冷汗|heart attack|chest pain|myocardial infarction)/i,
    variants: ['heart attack', 'chest pain', 'myocardial infarction'],
  },
  {
    pattern: /(烧伤|燒傷|烫伤|燙傷|热油烫|熱油燙|火烧伤|burns?|scald|thermal burn)/i,
    variants: ['burn', 'burns', 'scald', 'thermal burn'],
  },
  { pattern: /(中风|脑卒中|卒中|stroke|fast)/i, variants: ['stroke', 'face drooping', 'arm weakness', 'speech trouble'] },
  {
    pattern: /(脑震荡|颅脑损伤|头部外伤|头部撞击|concussion|tbi|traumatic brain injury)/i,
    variants: ['concussion', 'traumatic brain injury', 'head trauma'],
  },
  { pattern: /(蛇咬|毒蛇|snake bite|snakebite)/i, variants: ['snake bite', 'snakebite', 'venomous snakes'] },
  { pattern: /(蜘蛛咬|毒蜘蛛|spider bite|spider)/i, variants: ['spider bite', 'venomous spiders'] },
  { pattern: /(溺水|呛水|drowning|drown)/i, variants: ['drowning'] },
  { pattern: /(阿片|阿片类|纳洛酮|过量|opioid|overdose|naloxone)/i, variants: ['opioid', 'overdose', 'naloxone'] },
  { pattern: /(食物中毒|food poisoning)/i, variants: ['food poisoning', 'staphylococcal food poisoning'] },
  { pattern: /(植物中毒|毒草|毒植物|poisonous plants?)/i, variants: ['poisonous plants'] },
  { pattern: /(铅中毒|lead poisoning|lead exposure)/i, variants: ['lead poisoning'] },
  { pattern: /(中暑|热射病|热衰竭|高温|heat stroke|heat exhaustion|heat stress)/i, variants: ['heat stroke', 'heat stress', 'extreme heat'] },
  { pattern: /(冻伤|低体温|失温|frostbite|hypothermia)/i, variants: ['frostbite', 'hypothermia'] },
  { pattern: /(雷击|雷暴|打雷|lightning|thunderstorm)/i, variants: ['lightning', 'thunderstorm safety'] },
  { pattern: /(触电|电击|electric shock|electrical)/i, variants: ['electric shock', 'electrical safety'] },
  { pattern: /(哮喘|喘不过气|asthma|wheezing)/i, variants: ['asthma', 'respiratory'] },
  { pattern: /(狂犬|被狗咬|rabies|animal bite)/i, variants: ['rabies'] },
  { pattern: /(蜱虫|tick bite|ticks)/i, variants: ['ticks', 'tick bite'] },
  { pattern: /(洪水|内涝|flood)/i, variants: ['floods', 'storms and floods'] },
  { pattern: /(跌倒|摔伤|fall injury|falls)/i, variants: ['falls', 'injury'] },
  {
    pattern: /(战争|戰爭|炮击|炮擊|轰炸|轟炸|爆炸|枪击|槍擊|active shooter|blast|explosion|war zone)/i,
    variants: ['explosion safety', 'hard cover', 'shelter in place', 'crisis conflict'],
  },
  {
    pattern: /(核战|核戰|核爆|辐射|輻射|脏弹|髒彈|dirty bomb|radiation|nuclear|fallout|radiological)/i,
    variants: ['radiation emergency', 'nuclear emergency', 'fallout', 'dirty bomb'],
  },
  {
    pattern: /(病毒袭击|病毒攻擊|生物袭击|生物攻擊|疫情|大流行|anthrax|biohazard|biological attack|pandemic|outbreak)/i,
    variants: ['biohazard', 'biological attack', 'pandemic', 'anthrax'],
  },
  {
    pattern: /(ai攻击|ai攻擊|网络攻击|網絡攻擊|网络入侵|網絡入侵|cyberattack|cyber attack|ransomware|power outage|通信中断|通訊中斷)/i,
    variants: ['cyberattack', 'communications outage', 'power outage', 'infrastructure failure'],
  },
];

const LOW_SIGNAL_ENGLISH_QUERY_TERMS = new Set([
  'survival',
  'field',
  'travel',
  'basics',
  'emergency',
  'shelter',
  'wilderness',
  'outdoor',
  'government',
  'guidance',
  'visual',
  'help',
]);

function buildQueryVariants(input: string): string[] {
  const normalized = input.toLowerCase().trim();
  if (!normalized) {
    return [];
  }

  const variants = new Set<string>([normalized]);
  for (const rule of semanticQueryRules) {
    if (rule.pattern.test(normalized)) {
      for (const variant of rule.variants) {
        variants.add(variant.toLowerCase());
      }
    }
  }

  return [...variants];
}

export function createDefaultModels(): ModelDescriptor[] {
  return [
    {
      id: 'gemma-4-e2b',
      tier: 'e2b',
      name: 'Gemma 4 E2B',
      localPath: 'models/gemma-4-e2b.litertlm',
      sizeLabel: '2B / Survival Baseline',
      isLoaded: true,
      isDownloaded: true,
      supportsImageInput: true,
      supportsVision: true,
      downloadStatus: 'succeeded',
      artifactFormat: 'litertlm',
      runtimeStack: 'litert-lm-c-api',
      minCapabilityClass: 'ios-6gb-plus',
      preferredBackend: 'auto-real',
      capabilityClass: 'supported',
      supportedDeviceClass: 'unknown',
    },
    {
      id: 'gemma-4-e4b',
      tier: 'e4b',
      name: 'Gemma 4 E4B',
      localPath: 'models/gemma-4-e4b.litertlm',
      sizeLabel: '4B / Enhanced Accuracy',
      isLoaded: false,
      isDownloaded: false,
      supportsImageInput: true,
      supportsVision: true,
      downloadStatus: 'not_downloaded',
      artifactFormat: 'litertlm',
      runtimeStack: 'litert-lm-c-api',
      minCapabilityClass: 'ios-6gb-plus',
      preferredBackend: 'auto-real',
      capabilityClass: 'supported',
      supportedDeviceClass: 'unknown',
    },
  ];
}

function normalizeTerms(input: string): string[] {
  const queryVariants = buildQueryVariants(input);
  if (queryVariants.length === 0) {
    return [];
  }

  const coarseTerms: string[] = [];
  const cjkBigrams: string[] = [];

  for (const variant of queryVariants) {
    coarseTerms.push(
      ...variant
        .split(/[^a-z0-9\u4e00-\u9fff]+/)
        .map((term) => term.trim())
        .filter((term) => {
          if (!term) {
            return false;
          }
          if (/^[a-z]+$/.test(term) && LOW_SIGNAL_ENGLISH_QUERY_TERMS.has(term)) {
            return false;
          }
          return true;
        }),
    );

    const compact = variant.replace(/\s+/g, '');
    for (let index = 0; index < compact.length - 1; index += 1) {
      const pair = compact.slice(index, index + 2);
      if (/[\u4e00-\u9fff]/.test(pair)) {
        cjkBigrams.push(pair);
      }
    }
  }

  return [...new Set([...queryVariants, ...coarseTerms, ...cjkBigrams])];
}

function cardSearchText(card: KnowledgeCard): string {
  return [
    card.title,
    card.summary,
    ...card.steps,
    ...card.contraindications,
    card.escalation,
    ...card.tags,
    ...card.aliases,
    card.category,
  ]
    .join(' ')
    .toLowerCase();
}

function cardSourceText(card: KnowledgeCard): string {
  return [
    card.source,
    card.sourceId,
    card.sourceUrl ?? '',
    card.category,
    ...card.tags,
    ...card.aliases,
  ]
    .join(' ')
    .toLowerCase();
}

function getKnowledgeCardIndex(): Map<string, KnowledgeCard> {
  const cards = getKnowledgeCards();
  if (cards !== cachedKnowledgeCards || !cachedKnowledgeCardIndex) {
    cachedKnowledgeCards = cards;
    cachedKnowledgeCardIndex = new Map(cards.map((card) => [card.id, card]));
  }
  return cachedKnowledgeCardIndex;
}

function isOutdoorSurvivalQuery(query: string): boolean {
  return /(野外|户外|戶外|山里|山裡|森林|树林|樹林|林子|山林|林区|林區|徒步|登山|露营|露營|迷路|失联|失聯|没信号|沒有信號|求救|过夜|過夜|庇护|庇護|取火|生火|净水|淨水|溪水|打雷|雷暴|雷击|雷擊|山洪|暴雨|失温|失溫|冻伤|凍傷|中暑|蜱虫|蜱蟲|毒植物|蛇咬|蜘蛛咬|trip plan|ten essentials|wilderness|outdoor|forest|woods?|woodland|jungle|lost|stranded|shelter|water purification|lightning|hypothermia)/i.test(
    query,
  );
}

function isGenericWildernessContextQuery(query: string): boolean {
  const hasGenericOutdoorContext = /(野外|户外|戶外|山里|山裡|森林|树林|樹林|林子|山林|林区|林區|forest|woods?|woodland|jungle|wilderness|outdoor)/i.test(
    query,
  );
  const hasSpecificOutdoorNeed = /(迷路|失联|失聯|没信号|沒有信號|求救|天黑|过夜|過夜|庇护|庇護|取火|生火|净水|淨水|溪水|打雷|雷暴|雷击|雷擊|山洪|暴雨|失温|失溫|冻伤|凍傷|中暑|热射病|熱射病|蜱虫|蜱蟲|毒植物|蛇咬|蜘蛛咬|trip plan|ten essentials|lost|stranded|disconnected|shelter|water purification|lightning|hypothermia|frostbite|heat stroke|heat stress|tick bite|ticks|poisonous plants|snake bite|spider bite|flood)/i.test(
    query,
  );
  return hasGenericOutdoorContext && !hasSpecificOutdoorNeed;
}

function isOnSceneOutdoorContextQuery(query: string): boolean {
  return /(我在|人在|现在在|目前在|被困在|困在|正在|inside|in the|currently in|stuck in|surrounded by)/i.test(
    query,
  ) && /(野外|户外|戶外|山里|山裡|森林|树林|樹林|林子|山林|林区|林區|forest|woods?|woodland|jungle|wilderness|outdoor)/i.test(
    query,
  );
}

function isChestPainQuery(query: string): boolean {
  return /(胸痛|胸口痛|胸口很痛|胸闷|胸悶|心口痛|心脏痛|心臟痛|左臂痛|冒冷汗|heart attack|chest pain|myocardial infarction)/i.test(
    query,
  );
}

function isBurnQuery(query: string): boolean {
  return /(烧伤|燒傷|烫伤|燙傷|热油烫|熱油燙|火烧伤|burns?|scald|thermal burn)/i.test(query);
}

function isRadiationQuery(query: string): boolean {
  return /(核战|核戰|核爆|辐射|輻射|脏弹|髒彈|dirty bomb|radiation|nuclear|fallout|radiological)/i.test(query);
}

function isBioQuery(query: string): boolean {
  return /(病毒袭击|病毒攻擊|生物袭击|生物攻擊|疫情|大流行|anthrax|biohazard|biological attack|pandemic|outbreak|隔离|隔離|传染|傳染)/i.test(query);
}

function isCyberQuery(query: string): boolean {
  return /(ai攻击|ai攻擊|网络攻击|網絡攻擊|网络入侵|網絡入侵|cyberattack|cyber attack|ransomware|power outage|停电|停電|通信中断|通訊中斷|断网|斷網|infrastructure failure)/i.test(
    query,
  );
}

function isConflictQuery(query: string): boolean {
  return /(战争|戰爭|炮击|炮擊|轰炸|轟炸|爆炸|枪击|槍擊|空袭|空襲|war zone|blast|explosion|active shooter)/i.test(query);
}

function inferScenarioHint(
  rawCategoryHint: string,
  rawQuery: string,
): CanonicalScenarioHint | null {
  const explicitScenarioHint = normalizeScenarioHint(rawCategoryHint);
  if (explicitScenarioHint) {
    return explicitScenarioHint;
  }

  if (isOnSceneOutdoorContextQuery(rawQuery) || isGenericWildernessContextQuery(rawQuery)) {
    return CANONICAL_SCENARIO_HINTS.LOST_DISCONNECTED;
  }

  return null;
}

function sourceIntentBoost(card: KnowledgeCard, request: TriageRequest): number {
  const query = `${request.categoryHint ?? ''} ${request.userText}`.toLowerCase();
  const sourceText = cardSourceText(card);
  let boost = 0;

  if (isOutdoorSurvivalQuery(query)) {
    if (isGenericWildernessContextQuery(query)) {
      if (
        /(national park service|nps\.gov)/.test(sourceText) &&
        /(trip planning guide|outdoor emergency plan|ten essentials|wilderness travel basics|survival_|wilderness)/.test(
          sourceText,
        )
      ) {
        boost += 38;
      }

      if (/(fm-21-76|us army fm 21-76)/.test(sourceText)) {
        boost += 20;
      }

      if (
        /(tick|poisonous plants|venomous snakes|venomous spiders|encephalitis|relapsing fever|msd manual|merck manual|medlineplus|nhs)/.test(
          sourceText,
        ) &&
        !/(trip planning guide|outdoor emergency plan|ten essentials|wilderness travel basics|survival_|wilderness)/.test(
          sourceText,
        )
      ) {
        boost -= 18;
      }

      if (isOnSceneOutdoorContextQuery(query)) {
        if (/(wilderness travel basics|survival_|wilderness)/.test(sourceText)) {
          boost += 24;
        }

        if (/(trip planning guide|ten essentials|gear checklist|route plan)/.test(sourceText)) {
          boost -= 30;
        }
      }
    } else if (
      /(national park service|nps\.gov|weather\.gov|noaa|ready\.gov|cdc)/.test(sourceText) &&
      /(survival_|outdoor|trip plan|ten essentials|wilderness|lightning|flood|heat|hypothermia|tick|poisonous plants|venomous snakes|venomous spiders)/.test(
        sourceText,
      )
    ) {
      boost += 26;
    }

    if (/(fm-21-76|us army fm 21-76)/.test(sourceText) && !/(战争|戰爭|war|combat|军事|軍事|核战|核戰)/i.test(query)) {
      boost -= 10;
    }

    if (
      /(msd manual|merck manual|medlineplus|nhs)/.test(sourceText) &&
      /(野外|户外|戶外|山里|山裡|森林|树林|樹林|林子|山林|林区|林區|徒步|露营|露營|登山|迷路|断联|斷聯|没信号|沒有信號|庇护|庇護|取火|净水|淨水|天黑|求救|路线|路線|雷击|雷擊|雷暴|山洪|过夜|過夜)/.test(
        query,
      ) &&
      !/(蛇咬|蜘蛛|蜱虫|蜱蟲|毒植物|中暑|热射病|熱射病|失温|失溫|冻伤|凍傷|中毒|腹泻|腹瀉|呕吐|嘔吐|烧伤|燒傷|外伤|外傷|骨折)/.test(
        query,
      )
    ) {
      boost -= 8;
    }
  }

  if (
    isChestPainQuery(query) &&
    /(heart attack|myocardial infarction|acute coronary|cardiac|coronary|chest pain|胸痛|心梗|压榨痛)/.test(sourceText)
  ) {
    boost += 34;
  }

  if (isBurnQuery(query)) {
    if (/(burn|burns|scald|thermal burn|烧伤|燒傷|烫伤|燙傷)/.test(sourceText)) {
      boost += 30;
    }
    if (/(fm-21-76|us army fm 21-76)/.test(sourceText)) {
      boost -= 12;
    }
  }

  if (isRadiationQuery(query) && /(crisis_radiation|radiation|nuclear|radiological|fallout|dirty bomb|ready\.gov|cdc)/.test(sourceText)) {
    boost += 30;
  }

  if (isBioQuery(query) && /(crisis_bio|biohazard|pandemic|anthrax|hazmat|ready\.gov|cdc)/.test(sourceText)) {
    boost += 26;
  }

  if (isCyberQuery(query) && /(crisis_cyber|cyber|power outage|communications outage|get-tech-ready|infrastructure failure|ready\.gov|cisa)/.test(sourceText)) {
    boost += 28;
  }

  if (isConflictQuery(query) && /(crisis_conflict|explosion|hard cover|shelter in place|public-spaces|ready\.gov|radiation)/.test(sourceText)) {
    boost += 24;
  }

  return boost;
}

function isChunkFragmentCard(card: KnowledgeCard): boolean {
  return card.id.includes('-chunk-') || /#\d+\b/.test(card.title);
}

function isNoisyRetrievalCategory(category: string): boolean {
  return category === '全文网页' || category === '全文手册' || category === '数据集知识块';
}

function isNoisyRetrievalCard(card: KnowledgeCard): boolean {
  return isNoisyRetrievalCategory(card.category) || isChunkFragmentCard(card);
}

function retrievalQualityAdjustment(
  card: KnowledgeCard,
  request: TriageRequest,
  scenarioHint: CanonicalScenarioHint | null,
): number {
  const query = `${request.categoryHint ?? ''} ${request.userText}`.toLowerCase();
  const sourceText = cardSourceText(card);
  const searchText = cardSearchText(card);
  const noisyCard = isNoisyRetrievalCard(card);
  const isWholePage = card.category === '全文网页' || isChunkFragmentCard(card);
  const isManualChunk = card.category === '全文手册';
  const isDatasetChunk = card.category === '数据集知识块';
  const isImmediateEmergencyQuery = /(immediate|urgent|right now|help me survive|立刻|立即|马上|自救|保命|急救)/.test(
    query,
  );
  const isScenarioDrivenQuery =
    scenarioHint !== null
    || query.length <= 120
    || isOutdoorSurvivalQuery(query)
    || isConflictQuery(query)
    || isRadiationQuery(query)
    || isBioQuery(query)
    || isCyberQuery(query)
    || isChestPainQuery(query)
    || isBurnQuery(query);

  let adjustment = 0;

  if (isWholePage) {
    adjustment -= isScenarioDrivenQuery ? 18 : 8;

    if (/(ready\.gov|weather\.gov|noaa|nps\.gov|national park service|cdc|nih|ninds|red cross|nhs)/.test(sourceText)) {
      adjustment += 6;
    }

    if (/(merck|msd manual|medlineplus)/.test(sourceText)) {
      adjustment -= 6;
    }
  } else if (isManualChunk) {
    adjustment -= isScenarioDrivenQuery ? 8 : 3;
  } else if (isDatasetChunk) {
    adjustment -= isScenarioDrivenQuery ? 10 : 4;
  } else {
    adjustment += 8;
  }

  if (!noisyCard && card.priority >= 9) {
    adjustment += 4;
  }

  if (scenarioHint && !noisyCard) {
    const scenarioMatches = getScenarioRetrievalTerms(scenarioHint)
      .map((term) => term.toLowerCase())
      .filter((term) => term.length > 2 && searchText.includes(term))
      .length;
    adjustment += Math.min(18, scenarioMatches * 4);
  }

  if (
    scenarioHint === 'lost_disconnected'
    && isImmediateEmergencyQuery
    && /(survival_prep|野外生存准备)/.test(card.category.toLowerCase())
  ) {
    adjustment -= 16;
  }

  if (
    scenarioHint === 'trapped_in_fire'
    && isWholePage
    && /(merck|msd manual|medlineplus)/.test(sourceText)
  ) {
    adjustment -= 12;
  }

  return adjustment;
}

function localeAffinityBoost(card: KnowledgeCard, request: TriageRequest): number {
  const requestLocale = request.locale?.toLowerCase() ?? '';
  const cardLocale = card.locale?.toLowerCase() ?? '';
  const requestBase = requestLocale.split('-')[0];
  const cardBase = cardLocale.split('-')[0];
  const requestHasCjk = /[\u4e00-\u9fff]/.test(`${request.categoryHint ?? ''} ${request.userText}`);
  const cardHasCjk = /[\u4e00-\u9fff]/.test([card.title, card.summary, ...card.aliases, ...card.tags].join(' '));
  const noisyCategory = isNoisyRetrievalCard(card);

  let boost = 0;
  if (requestBase && cardBase && requestBase === cardBase) {
    boost += noisyCategory ? 6 : 18;
  }
  if (requestHasCjk && cardHasCjk) {
    boost += noisyCategory ? 6 : 16;
  }
  return boost;
}

function limitEvidenceBySource(items: RetrievedKnowledge[], maxPerSource: number): RetrievedKnowledge[] {
  const sourceCounts = new Map<string, number>();
  const limited: RetrievedKnowledge[] = [];

  for (const item of items) {
    const seen = sourceCounts.get(item.sourceId) ?? 0;
    if (seen >= maxPerSource) {
      continue;
    }
    sourceCounts.set(item.sourceId, seen + 1);
    limited.push(item);
  }

  return limited;
}

function compactWhitespace(input: string | undefined): string {
  return (input ?? '').replace(/\s+/g, ' ').trim();
}

function compactSnippet(input: string | undefined, maxChars: number): string {
  const normalized = compactWhitespace(input);
  if (normalized.length <= maxChars) {
    return normalized;
  }
  return `${normalized.slice(0, Math.max(0, maxChars - 3)).trimEnd()}...`;
}

function cleanGroundingSnippet(input: string | undefined, maxChars: number): string {
  return compactSnippet(input, maxChars)
    .replace(/\$\s*l?rightarrow\s*\$/gi, '->')
    .replace(/\bstrightarrow\b/gi, '->')
    .replace(/^(?:A|S|Do|Avoid|Help)\s*:\s*/i, '')
    .trim();
}

function isOutdoorHazardCard(card: KnowledgeCard): boolean {
  const haystack = [
    card.title,
    card.summary,
    card.category,
    ...card.tags,
    ...card.aliases,
    card.source,
    card.sourceId,
  ]
    .join(' ')
    .toLowerCase();

  return /(heat|中暑|热射病|熱射病|lightning|雷击|雷擊|雷暴|flood|山洪|洪水|tick|ticks|蜱虫|蜱蟲|snake bite|snakebite|蛇咬|venomous snakes|spider bite|spider|蜘蛛|venomous spiders|poisonous plants|毒植物|hypothermia|失温|失溫|frostbite|冻伤|凍傷)/.test(
    haystack,
  );
}

function hasSpecificOutdoorHazardQuery(query: string): boolean {
  return /(中暑|热射病|熱射病|heat stroke|heat stress|lightning|雷击|雷擊|雷暴|flood|山洪|洪水|tick|ticks|蜱虫|蜱蟲|snake bite|snakebite|蛇咬|spider bite|spider|蜘蛛|poisonous plants|毒植物|hypothermia|失温|失溫|frostbite|冻伤|凍傷)/i.test(
    query,
  );
}

function shouldFilterOutdoorHazards(query: string, categoryHint: string): boolean {
  if (hasSpecificOutdoorHazardQuery(query)) {
    return false;
  }

  if (isGenericWildernessContextQuery(query)) {
    return true;
  }

  return /(迷路|失联|失聯|lost|stranded|disconnected)/i.test(`${categoryHint} ${query}`);
}

export function retrieveEvidenceBundle(request: TriageRequest): EvidenceBundle {
  const knowledgeCards = getKnowledgeCards();
  const rawCategoryHint = request.categoryHint?.trim() ?? '';
  const rawQuery = [rawCategoryHint, request.userText].filter(Boolean).join(' ').trim();
  const scenarioHint = inferScenarioHint(rawCategoryHint, rawQuery);
  const scenarioTerms = getScenarioRetrievalTerms(scenarioHint);
  const primaryScenarioCategories = new Set(
    getScenarioPrimaryCategories(scenarioHint).map((category) => category.toLowerCase()),
  );
  const directCategoryHints = new Set(
    [
      rawCategoryHint.toLowerCase(),
      ...primaryScenarioCategories,
    ].filter(Boolean),
  );
  const query = [rawQuery, ...scenarioTerms].filter(Boolean).join(' ').trim();
  const queryVariants = [...new Set([...buildQueryVariants(query), ...scenarioTerms.map((term) => term.toLowerCase())])];
  const queryTerms = [...new Set([...normalizeTerms(query), ...normalizeTerms(scenarioTerms.join(' '))])];
  const directHits: RetrievedKnowledge[] = [];
  const lexicalHits: RetrievedKnowledge[] = [];
  const matchedCategories = new Set<string>();

  for (const card of knowledgeCards) {
    const normalizedCategory = card.category.toLowerCase();
    const searchText = cardSearchText(card);
    const affinityBoost = localeAffinityBoost(card, request);
    const sourceBoost = sourceIntentBoost(card, request);
    const qualityAdjustment = retrievalQualityAdjustment(card, request, scenarioHint);

    const matchesPrimaryScenarioCategory = primaryScenarioCategories.has(normalizedCategory);
    const matchesDirectCategoryHint = [...directCategoryHints].some((hint) =>
      normalizedCategory.includes(hint) || hint.includes(normalizedCategory),
    );

    if (matchesDirectCategoryHint) {
      const directBaseScore = matchesPrimaryScenarioCategory ? 180 : 120;
      directHits.push(
        knowledgeCardToRetrieved(
          card,
          directBaseScore + card.priority + affinityBoost + sourceBoost + qualityAdjustment,
          'directRule',
        ),
      );
      matchedCategories.add(card.category);
      continue;
    }

    let tagScore = 0;
    let termScore = 0;
    for (const tag of [card.category, ...card.tags, ...card.aliases]) {
      const normalizedTag = tag.toLowerCase();
      if (!normalizedTag) {
        continue;
      }
      if (queryVariants.some((variant) => variant.includes(normalizedTag) || normalizedTag.includes(variant))) {
        tagScore += normalizedTag.length <= 2 ? 8 : 22;
      }
    }

    for (const term of queryTerms) {
      if (searchText.includes(term)) {
        termScore += term.length <= 2 ? 6 : 10;
      }
    }

    const score = Math.min(tagScore, 60) + Math.min(termScore, 80);
    const totalScore = score + card.priority + affinityBoost + sourceBoost + qualityAdjustment;
    if (score > 0 && totalScore > 0) {
      lexicalHits.push(knowledgeCardToRetrieved(card, totalScore, 'lexical'));
      if (totalScore >= 20) {
        matchedCategories.add(card.category);
      }
    }
  }

  const merged = [...directHits, ...lexicalHits]
    .sort((left, right) => {
      const scoreDelta = right.score - left.score;
      if (scoreDelta !== 0) {
        return scoreDelta;
      }
      const leftCard = findCardById(left.id);
      const rightCard = findCardById(right.id);
      const affinityDelta =
        (rightCard ? localeAffinityBoost(rightCard, request) : 0) -
        (leftCard ? localeAffinityBoost(leftCard, request) : 0);
      if (affinityDelta !== 0) {
        return affinityDelta;
      }
      return right.title.localeCompare(left.title);
    })
    .filter((item, index, list) => list.findIndex((candidate) => candidate.id === item.id) === index);
  const diversified = limitEvidenceBySource(merged, 1);

  const filtered = shouldFilterOutdoorHazards(query, [rawCategoryHint, ...scenarioTerms].join(' ').toLowerCase())
    ? diversified.filter((item) => {
        const card = findCardById(item.id);
        return card ? !isOutdoorHazardCard(card) : true;
      })
    : diversified;
  const ranked = filtered.length > 0 ? filtered : diversified;

  const authoritative = ranked.filter((item) => item.score >= 40).slice(0, 4);
  const supporting = ranked
    .filter((item) => !authoritative.some((saved) => saved.id === item.id))
    .slice(0, 2);

  return {
    authoritative,
    supporting,
    matchedCategories: [...matchedCategories],
    queryTerms,
  };
}

export function buildGroundingContext(evidence: EvidenceBundle): string {
  const reliableSupporting = evidence.supporting.filter((item) => {
    const card = findCardById(item.id);
    const noisyCard = card ? isNoisyRetrievalCard(card) : false;
    const minScore = evidence.authoritative.length > 0 ? 24 : 32;
    const strongStandaloneSupport =
      item.strategy === 'directRule'
      || (card ? card.priority >= 9 && !noisyCard : false);

    if (noisyCard) {
      return false;
    }

    if (evidence.authoritative.length === 0) {
      return item.score >= minScore && strongStandaloneSupport;
    }

    return item.score >= minScore;
  });
  const preferredGroundingItems = [...evidence.authoritative, ...reliableSupporting];
  const hasStructuredCandidate = preferredGroundingItems.some((item) => {
    const card = findCardById(item.id);
    return card ? !isNoisyRetrievalCard(card) : false;
  });
  const groundingItems = preferredGroundingItems
    .filter((item) => {
      const card = findCardById(item.id);
      if (!card) {
        return true;
      }
      return !hasStructuredCandidate || !isNoisyRetrievalCard(card);
    })
    .slice(0, 2);
  const lines: string[] = [];
  const seen = new Set<string>();
  const pushLine = (line: string): boolean => {
    if (!line) {
      return true;
    }
    const dedupeKey = line.toLowerCase();
    if (seen.has(dedupeKey)) {
      return true;
    }
    const next = lines.length === 0 ? line.length : lines.join('\n').length + 1 + line.length;
    if (next > GROUNDING_MAX_CHARS) {
      return false;
    }
    lines.push(line);
    seen.add(dedupeKey);
    return true;
  };

  for (const [index, item] of groundingItems.entries()) {
    const summary = cleanGroundingSnippet(item.summary, GROUNDING_SUMMARY_CHARS);
    if (summary && !pushLine(`- ${summary}`)) {
      break;
    }

    const actions = item.steps.length > 0 ? item.steps.slice(0, index === 0 ? 3 : 2) : [item.summary];
    for (const action of actions) {
      const line = cleanGroundingSnippet(action, GROUNDING_STEP_CHARS);
      if (line && !pushLine(`- ${line}`)) {
        return lines.join('\n');
      }
    }

    for (const warning of item.contraindications.slice(0, 2)) {
      const line = cleanGroundingSnippet(warning, 72);
      if (line && !pushLine(`- ${line}`)) {
        return lines.join('\n');
      }
    }

    const escalation = cleanGroundingSnippet(item.escalation, GROUNDING_ESCALATION_CHARS);
    if (escalation && !pushLine(`- ${escalation}`)) {
      return lines.join('\n');
    }
  }

  return lines.join('\n');
}

function chooseProfile(powerMode: PowerMode): string {
  return powerMode === 'doomsday' ? 'gemma-4-e2b-saver' : 'gemma-4-e2b-balanced';
}

function findCardById(id: string): KnowledgeCard | undefined {
  return getKnowledgeCardIndex().get(id);
}

function pickPrimaryKnowledgeCard(
  request: TriageRequest,
  evidence: EvidenceBundle,
): KnowledgeCard | undefined {
  const candidates = [...evidence.authoritative, ...evidence.supporting]
    .map((item) => {
      const card = findCardById(item.id);
      if (!card) {
        return null;
      }
      return { card, score: item.score };
    })
    .filter((candidate): candidate is { card: KnowledgeCard; score: number } => candidate !== null)
    .sort((left, right) => {
      const scoreDelta = right.score - left.score;
      if (scoreDelta !== 0) {
        return scoreDelta;
      }
      const affinityDelta = localeAffinityBoost(right.card, request) - localeAffinityBoost(left.card, request);
      if (affinityDelta !== 0) {
        return affinityDelta;
      }
      return right.card.title.localeCompare(left.card.title);
    });

  return candidates[0]?.card;
}

function buildGroundedResponse(
  request: TriageRequest,
  evidence: EvidenceBundle,
): TriageResponse | null {
  if (evidence.authoritative.length === 0) {
    return null;
  }
  const card = pickPrimaryKnowledgeCard(request, evidence);
  if (!card) {
    return null;
  }

  return {
    summary: card.summary,
    steps: [...card.steps],
    disclaimer: translateMessage(request.locale, 'disclaimer.authoritative'),
    isKnowledgeBacked: true,
    guidanceMode: 'grounded',
    evidence,
    usedProfileName: chooseProfile(request.powerMode),
  };
}

function buildAiBestEffortResponse(
  request: TriageRequest,
  evidence: EvidenceBundle,
): TriageResponse {
  const query = `${request.categoryHint ?? ''} ${request.userText}`.toLowerCase();
  const imageContext = request.imageBase64
    ? '若画面显示持续出血、呼吸困难、面色发青或明显肿胀，优先按最危重情况处理。'
    : '';
  const context = buildContextualBestEffortPlan(query, imageContext);

  return {
    summary: context.summary,
    steps: context.steps,
    disclaimer: translateMessage(request.locale, 'disclaimer.limited_evidence'),
    isKnowledgeBacked: false,
    guidanceMode: 'grounded',
    evidence,
    usedProfileName: chooseProfile(request.powerMode),
  };
}

function buildContextualBestEffortPlan(
  query: string,
  imageContext: string,
): { summary: string; steps: string[] } {
  if (/(核战|核戰|核爆|辐射|輻射|dirty bomb|radiation|nuclear|fallout|radiological)/.test(query)) {
    return {
      summary: '先按放射性尘降处理，核心是立刻进入厚实建筑、减少外暴露，再等待官方信息。',
      steps: [
        '立即进入最近的坚固建筑，尽量去地下或建筑中央，远离外墙、屋顶和窗户。',
        '关闭门窗和外循环，先稳定待住，不要在户外继续围观或长距离转移。',
        imageContext || '若怀疑沾到粉尘，进室内后先脱外层衣物并温和清洗，再等待官方指引。',
      ],
    };
  }

  if (/(病毒袭击|病毒攻擊|生物袭击|生物攻擊|biohazard|biological attack|pandemic|outbreak|anthrax)/.test(query)) {
    return {
      summary: '先按生物暴露或传染事件处理，目标是隔离、通风、防护并保留暴露信息。',
      steps: [
        '立刻把有症状者与其他人分开，减少近距离接触并尽量改善通风。',
        '准备口罩、单独餐具和垃圾处理，记录发病时间、暴露地点与接触者。',
        imageContext || '若多人同时发病、症状快速恶化或怀疑可疑粉末暴露，恢复通信后立刻求助公共卫生和急救系统。',
      ],
    };
  }

  if (/(ai攻击|ai攻擊|网络攻击|網絡攻擊|cyberattack|cyber attack|ransomware|power outage|通信中断|通訊中斷|断网|斷網)/.test(query)) {
    return {
      summary: '先按网络与基础设施故障处理，保住电量、可信渠道和离线生存能力。',
      steps: [
        '停止点击未知链接和二维码，断开可疑网络连接，只信任官方警报与已验证联系人。',
        '立刻切低功耗，启用离线地图、短信、手电和收音机，保留核心设备电量。',
        imageContext || '若停电停网已经影响饮水、照明、医疗或夜间安全，按长期停电方案转入家庭或社区应急模式。',
      ],
    };
  }

  if (/(战争|戰爭|炮击|炮擊|轰炸|轟炸|爆炸|枪击|槍擊|blast|explosion|active shooter)/.test(query)) {
    return {
      summary: '先把情况视为持续危险现场，核心是找硬掩体、离开玻璃和开放区域，再等更安全时移动。',
      steps: [
        '立刻趴低并远离窗户、外墙、车辆和裸露开阔地，优先寻找承重墙后或更低层的坚固掩体。',
        '不要在第一轮冲击后马上站起来围观，警惕二次爆炸、坍塌、烟火和持续枪声。',
        imageContext || '若必须移动，优先短距离转移到更厚实的掩护点，并用短信而不是长时间通话联络。',
      ],
    };
  }

  if (/(野外|户外|戶外|山里|山裡|森林|树林|樹林|林子|山林|林区|林區|forest|woods?|woodland|jungle|wilderness|outdoor)/.test(query)) {
    return {
      summary: '先把自己当成野外生存场景处理，先确认方向、天色、气温、水源和是否受伤。',
      steps: [
        '先停下来，不要一边慌着继续走一边发消息；先确认当前位置、手机电量、天色和能否原路返回。',
        '优先远离悬崖、急水、倒木、裸露山脊和明显动物活动痕迹，找相对安全又容易被发现的位置。',
        '先整理能立刻用的保命资源：保暖层、饮水容器、照明、充电、电量和能发出求救信号的工具。',
        '如果天快黑、天气变差或拿不准方向，优先准备保暖和求救，不要在体力下降后盲目深走。',
        imageContext || '一旦同时出现迷路、失温、外伤、蛇咬或持续无信号，就马上按更具体的野外急救场景处理。',
      ],
    };
  }

  if (/(阿片|阿片类|纳洛酮|过量|overdose|opioid|naloxone)/.test(query)) {
    return {
      summary: '先按药物过量伴呼吸抑制处理，核心是保气道、尽快给纳洛酮并持续盯住呼吸。',
      steps: [
        '立刻大声呼喊和轻拍刺激，确认是否能唤醒；同时准备呼叫急救。',
        '若呼吸很慢、很浅或嘴唇发青，先开放气道；有纳洛酮时按说明尽快使用。',
        imageContext || '若依旧无正常呼吸，立刻开始 CPR 或人工呼吸，并持续观察直到有人接手。',
      ],
    };
  }

  if (/(低血糖|血糖太低|hypoglycemia|low blood sugar|diabetic|糖尿病)/.test(query)) {
    return {
      summary: '先按低血糖处理，人清醒能吞咽就快速补糖，意识差时只保气道不要硬喂。',
      steps: [
        '若人清醒且能吞咽，立即给含糖饮料、葡萄糖片或糖包这类快速糖分。',
        '大约 15 分钟后再评估一次；如果仍明显手抖、出汗、发懵，可以再补一次。',
        imageContext || '若意识差、抽搐或吞咽不安全，不要强灌食物饮料，恢复通信后立刻急救。',
      ],
    };
  }

  if (/(胸痛|胸闷|心口痛|心脏|heart|chest pain)/.test(query)) {
    return {
      summary: '先按潜在心肺急症处理，立刻减少活动并持续观察呼吸与意识。',
      steps: [
        '立即停下活动，取半坐位或最容易呼吸的姿势，保持安静。',
        '若伴随冒冷汗、呼吸困难、疼痛放射到左臂/下巴，不要继续行走或负重。',
        imageContext || '准备好位置信息与发作时间，一旦恢复通信立刻呼叫急救。',
      ],
    };
  }

  if (/(烧伤|燒傷|烫伤|燙傷|热油烫|熱油燙|burn|burns|scald|thermal burn)/.test(query)) {
    return {
      summary: '先按热力烧伤处理，核心是立即降温、去除继续烫伤源并保护创面。',
      steps: [
        '立刻用流动凉水持续冲洗烧伤处至少 20 分钟，同时移开热源和仍在发热的衣物饰品。',
        '若衣物粘在皮肤上，不要硬撕；轻轻覆盖干净敷料或保鲜膜样的非黏附覆盖物。',
        imageContext || '不要涂牙膏、酱油、油膏或冰块；若面积大、在面部手部会阴，或出现水泡焦黑，恢复通信后立刻求救。',
      ],
    };
  }

  if (/(无反应|叫不醒|昏过去还有呼吸|unresponsive|recovery position)/.test(query)) {
    return {
      summary: '先把情况视为高危意识障碍，核心是判断呼吸、侧卧保气道并随时准备转入 CPR。',
      steps: [
        '先确认有没有正常呼吸；若没有正常呼吸，立刻按心搏骤停处理。',
        '若还有呼吸，把人转成侧卧恢复体位，避免呕吐物或分泌物堵住气道。',
        imageContext || '每几分钟复查一次呼吸和反应，只要呼吸停止或明显变差就马上急救。',
      ],
    };
  }

  if (/(发烧|高烧|抽搐|昏迷|意识不清|fever|seizure|unconscious)/.test(query)) {
    return {
      summary: '先把情况视为高风险全身急症，优先保护气道、降温并防止二次伤害。',
      steps: [
        '若人已意识差或抽搐，先清理口鼻周围，侧卧并保持气道通畅。',
        '若体温明显过高，用湿布、通风或水冷方式持续降温，但不要强灌液体。',
        imageContext || '记录抽搐、高热或昏迷开始时间，通信恢复后立刻请求急救支援。',
      ],
    };
  }

  if (/(头部外伤|脑震荡|脑损伤|颈椎|脊柱|head injury|concussion|tbi|spinal)/.test(query)) {
    return {
      summary: '先按头颈部创伤处理，减少移动并持续盯住意识、呕吐和瞳孔变化。',
      steps: [
        '让伤者尽量保持不动，特别是怀疑颈椎受伤时不要随意扶起或扭头。',
        '若出现反复呕吐、越来越困、抽搐或单侧无力，立刻按高危颅脑损伤处理。',
        imageContext || '若无反应但还有呼吸，尽量整轴侧转保持气道；恢复通信后第一时间求助转运。',
      ],
    };
  }

  if (/(喘|哮喘|呼吸困难|喘不上气|窒息|smoke|breath|asthma|choking)/.test(query)) {
    return {
      summary: '先按呼吸受威胁处理，立刻改善通气并减少一切体力消耗。',
      steps: [
        '尽快离开烟尘、过敏源或拥挤闷热环境，保持坐起前倾姿势。',
        '松开勒住胸颈的衣物，尽量缓慢深呼吸；若说话已断句，视为重症。',
        imageContext || '如果嘴唇发青、呼吸越来越浅或无法完整说话，恢复通信后必须第一时间呼救。',
      ],
    };
  }

  if (/(休克|shock|冷汗|面色苍白|脉快|血压塌|快不行了)/.test(query)) {
    return {
      summary: '先按休克处理，平躺保暖、处理可逆原因并持续监测呼吸和意识。',
      steps: [
        '立刻让患者平躺保暖，优先寻找并处理大出血、呼吸困难或严重过敏等原因。',
        '若没有胸痛、呼吸困难或明显头胸伤，可谨慎抬高下肢帮助回心血量。',
        imageContext || '不要喂食喂水，也不要让人起身活动；恢复通信后必须尽快急救。',
      ],
    };
  }

  if (/(肚子|腹痛|腹部|呕吐|腹泻|poison|poisoning|vomit|abdominal)/.test(query)) {
    return {
      summary: '先按腹部或中毒类急症谨慎处理，防脱水、避免误食和继续刺激。',
      steps: [
        '先停止进食不明食物、药物或野外植物，保留可疑来源方便后续求助。',
        '若反复呕吐或腹痛加剧，少量多次补水；若意识差，暂时不要喂食喂水。',
        imageContext || '若出现黑便、呕血、腹部板硬或持续加重，通信恢复后立即联系急救。',
      ],
    };
  }

  if (/(摔|骨折|扭伤|撞伤|头部|流血|bleed|fracture|fall|head)/.test(query)) {
    return {
      summary: '先按外伤处理，优先止血、固定并减少不必要移动。',
      steps: [
        '先确认有没有持续出血；若有，立刻直接压迫止血并保持加压。',
        '怀疑骨折或头部受伤时，尽量固定原位，不要强行扶起或扭动伤者。',
        imageContext || '持续观察意识、瞳孔、呕吐和肢体活动，一旦通信恢复立刻请求转运。',
      ],
    };
  }

  return {
    summary: '先按最危重但可逆的问题排查，优先处理呼吸、出血、意识和体温。',
    steps: [
      '先确认现场安全，再判断有没有大出血、呼吸困难、昏迷或持续恶化。',
      '若有出血先压迫止血；若反应差先清气道、看呼吸，并尽量让伤者保暖静止。',
      imageContext || '把最早出现的症状、持续时间和加重诱因记下来，通信恢复后立刻求助。',
    ],
  };
}

export function inferTriageResponse(request: TriageRequest): TriageResponse {
  const evidence = retrieveEvidenceBundle(request);
  const grounded = buildGroundedResponse(request, evidence);
  if (grounded) {
    return grounded;
  }
  return buildAiBestEffortResponse(request, evidence);
}

export async function warmKnowledgeEngine(): Promise<void> {
  await ensureKnowledgeBaseLoaded();
}

export function splitStreamingTokens(response: TriageResponse): string[] {
  return [response.summary, ...response.steps]
    .join('\n')
    .split(/(?<=。|，|；|\n)/)
    .filter(Boolean);
}

export function estimateSosState(summary: string, active: boolean): SosState {
  return {
    active,
    connectedPeers: active ? Math.min(12, Math.max(2, Math.ceil(summary.length / 8))) : 0,
    lastBroadcastAt: active ? new Date().toISOString() : undefined,
  };
}

export async function* simulateDownload(
  modelId: string,
): AsyncIterable<ModelDownloadProgress> {
  const totalBytes = 100;
  for (const [index, receivedBytes] of [20, 45, 72, 100].entries()) {
    await sleep(150);
    yield {
      modelId,
      receivedBytes,
      totalBytes,
      fraction: receivedBytes / totalBytes,
      isResumed: receivedBytes > 20,
      status: index === 0 ? 'in_progress' : receivedBytes === 100 ? 'succeeded' : 'in_progress',
      bytesPerSecond: receivedBytes === 100 ? 0 : 160,
      remainingMs: receivedBytes === 100 ? 0 : Math.max(0, ((totalBytes - receivedBytes) / 160) * 1000),
    };
  }
}
