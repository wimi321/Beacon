import type { RetrievedKnowledge } from './types';

export type KnowledgeCard = {
  id: string;
  title: string;
  source: string;
  summary: string;
  steps: readonly string[];
  contraindications: readonly string[];
  escalation: string;
  tags: readonly string[];
  aliases: readonly string[];
  category: string;
  priority: number;
  sourceId: string;
  sourceUrl?: string;
  locale?: string;
  severity?: string;
};

export type KnowledgeSource = {
  id: string;
  authority: string;
  title: string;
  finalUrl: string;
  fileName: string;
  ext: string;
};

type OfflineKnowledgePayload = {
  version: number;
  generatedAt: string;
  sources: KnowledgeSource[];
  entries: KnowledgeCard[];
};

let payload: OfflineKnowledgePayload | null = null;
let loadPromise: Promise<OfflineKnowledgePayload> | null = null;

function knowledgeUrl(): string {
  const base = import.meta.env.BASE_URL || '/';
  return `${base.endsWith('/') ? base : `${base}/`}knowledge/offline_knowledge.json`;
}

function normalizeCard(card: KnowledgeCard): KnowledgeCard {
  return {
    ...card,
    steps: [...card.steps],
    contraindications: [...card.contraindications],
    tags: [...card.tags],
    aliases: [...card.aliases],
  };
}

export async function ensureKnowledgeBaseLoaded(): Promise<OfflineKnowledgePayload> {
  if (payload) {
    return payload;
  }

  if (!loadPromise) {
    loadPromise = fetch(knowledgeUrl(), { cache: 'force-cache' })
      .then(async (response) => {
        if (!response.ok) {
          throw new Error(`Failed to load offline knowledge bundle: ${response.status} ${response.statusText}`);
        }
        return response.json() as Promise<OfflineKnowledgePayload>;
      })
      .then((data) => {
        payload = {
          ...data,
          sources: [...data.sources],
          entries: data.entries.map(normalizeCard),
        };
        return payload;
      });
  }

  return loadPromise;
}

export function getKnowledgeCards(): KnowledgeCard[] {
  if (!payload) {
    throw new Error('Offline knowledge bundle is not loaded yet. Call ensureKnowledgeBaseLoaded() first.');
  }

  return payload.entries;
}

export function getKnowledgeSources(): KnowledgeSource[] {
  if (!payload) {
    throw new Error('Offline knowledge bundle is not loaded yet. Call ensureKnowledgeBaseLoaded() first.');
  }

  return payload.sources;
}

export function getKnowledgeStats(): { sourceCount: number; entryCount: number } {
  if (!payload) {
    throw new Error('Offline knowledge bundle is not loaded yet. Call ensureKnowledgeBaseLoaded() first.');
  }

  return {
    sourceCount: payload.sources.length,
    entryCount: payload.entries.length,
  };
}

export function resetKnowledgeBaseForTests(): void {
  payload = null;
  loadPromise = null;
}

export function knowledgeCardToRetrieved(card: KnowledgeCard, score: number, strategy: RetrievedKnowledge['strategy']): RetrievedKnowledge {
  return {
    id: card.id,
    sourceId: card.sourceId,
    title: card.title,
    source: card.source,
    summary: card.summary,
    steps: [...card.steps],
    contraindications: [...card.contraindications],
    escalation: card.escalation,
    strategy,
    score,
  };
}
