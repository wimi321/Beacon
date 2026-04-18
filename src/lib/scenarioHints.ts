import { messages, type TranslationKey } from '../i18n/messages';

export const CANONICAL_SCENARIO_HINTS = {
  LOST_DISCONNECTED: 'lost_disconnected',
  EARTHQUAKE_RUINS: 'earthquake_ruins',
  TRAPPED_IN_FIRE: 'trapped_in_fire',
  SEVERE_TRAUMA: 'severe_trauma',
  VISUAL_HELP: 'visual_help',
} as const;

export type CanonicalScenarioHint =
  typeof CANONICAL_SCENARIO_HINTS[keyof typeof CANONICAL_SCENARIO_HINTS];

type ScenarioDefinition = {
  translationKey: TranslationKey;
  primaryCategories: string[];
  retrievalTerms: string[];
  extraAliases: string[];
};

const SCENARIO_HINT_DEFINITIONS: Record<CanonicalScenarioHint, ScenarioDefinition> = {
  [CANONICAL_SCENARIO_HINTS.LOST_DISCONNECTED]: {
    translationKey: 'panic.lost.label',
    primaryCategories: ['迷路断联'],
    retrievalTerms: [
      '迷路',
      '断联',
      'lost',
      'stranded',
      'disconnected',
      'no signal',
      'wilderness',
      'survival field',
      'signaling for rescue',
    ],
    extraAliases: [
      'lost disconnected',
      'lost/disconnected',
      'lost and disconnected',
      'no signal',
      'out of signal',
    ],
  },
  [CANONICAL_SCENARIO_HINTS.EARTHQUAKE_RUINS]: {
    translationKey: 'panic.quake.label',
    primaryCategories: ['地震废墟'],
    retrievalTerms: [
      '地震',
      '废墟',
      'earthquake',
      'earthquake ruins',
      'rubble',
      'collapsed building',
      'trapped under debris',
    ],
    extraAliases: [
      'earthquake ruins',
      'earthquake rubble',
      'trapped in rubble',
    ],
  },
  [CANONICAL_SCENARIO_HINTS.TRAPPED_IN_FIRE]: {
    translationKey: 'panic.fire.label',
    primaryCategories: ['火场被困'],
    retrievalTerms: [
      '火场被困',
      '浓烟',
      'smoke',
      'fire',
      'wildfire',
      'trapped in fire',
      'smoke inhalation',
    ],
    extraAliases: [
      'trapped in fire',
      'fire trapped',
      'surrounded by smoke',
      'stuck in fire',
    ],
  },
  [CANONICAL_SCENARIO_HINTS.SEVERE_TRAUMA]: {
    translationKey: 'panic.trauma.label',
    primaryCategories: ['致命外伤'],
    retrievalTerms: [
      '致命外伤',
      '严重外伤',
      'major trauma',
      'severe trauma',
      'massive bleeding',
      'bleeding',
      'tourniquet',
      'wound packing',
      'fracture',
    ],
    extraAliases: [
      'severe trauma',
      'major trauma',
      'life threatening trauma',
      'critical injury',
    ],
  },
  [CANONICAL_SCENARIO_HINTS.VISUAL_HELP]: {
    translationKey: 'action.visual_help',
    primaryCategories: [],
    retrievalTerms: [
      'visual help',
      'wound',
      'bleeding',
      'bite',
      'snake bite',
      'spider bite',
      'tick bite',
      'burn',
      'rash',
      'fracture',
      'poisoning',
    ],
    extraAliases: [
      'visual help',
      'scan wound',
      'camera help',
      'analyze image',
    ],
  },
};

function normalizeScenarioToken(value: string): string {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[_/|]+/g, ' ')
    .replace(/[^\p{L}\p{N}\u4e00-\u9fff]+/gu, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function registerAlias(
  aliasIndex: Map<string, CanonicalScenarioHint>,
  alias: string,
  scenario: CanonicalScenarioHint,
): void {
  const normalized = normalizeScenarioToken(alias);
  if (!normalized) {
    return;
  }

  aliasIndex.set(normalized, scenario);

  const compact = normalized.replace(/\s+/g, '');
  if (compact && compact !== normalized) {
    aliasIndex.set(compact, scenario);
  }
}

function buildScenarioAliasIndex(): Map<string, CanonicalScenarioHint> {
  const aliasIndex = new Map<string, CanonicalScenarioHint>();

  for (const [scenario, definition] of Object.entries(SCENARIO_HINT_DEFINITIONS) as Array<
    [CanonicalScenarioHint, ScenarioDefinition]
  >) {
    registerAlias(aliasIndex, scenario, scenario);

    for (const primaryCategory of definition.primaryCategories) {
      registerAlias(aliasIndex, primaryCategory, scenario);
    }

    for (const alias of definition.extraAliases) {
      registerAlias(aliasIndex, alias, scenario);
    }

    const translatedLabels = Object.values(messages)
      .map((dictionary) => dictionary[definition.translationKey])
      .filter((label): label is string => typeof label === 'string' && label.trim().length > 0);

    for (const translatedLabel of translatedLabels) {
      registerAlias(aliasIndex, translatedLabel, scenario);
    }
  }

  return aliasIndex;
}

const SCENARIO_ALIAS_INDEX = buildScenarioAliasIndex();

export function normalizeScenarioHint(hint?: string | null): CanonicalScenarioHint | null {
  const normalized = normalizeScenarioToken(hint ?? '');
  if (!normalized) {
    return null;
  }

  return SCENARIO_ALIAS_INDEX.get(normalized)
    ?? SCENARIO_ALIAS_INDEX.get(normalized.replace(/\s+/g, ''))
    ?? null;
}

export function getScenarioPrimaryCategories(
  scenario: CanonicalScenarioHint | null | undefined,
): string[] {
  if (!scenario) {
    return [];
  }
  return [...SCENARIO_HINT_DEFINITIONS[scenario].primaryCategories];
}

export function getScenarioRetrievalTerms(
  scenario: CanonicalScenarioHint | null | undefined,
): string[] {
  if (!scenario) {
    return [];
  }

  const definition = SCENARIO_HINT_DEFINITIONS[scenario];
  return [...definition.primaryCategories, ...definition.retrievalTerms];
}
