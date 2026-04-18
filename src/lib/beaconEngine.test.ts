import { beforeAll, describe, expect, it } from 'vitest';
import { buildGroundingContext, inferTriageResponse, retrieveEvidenceBundle, warmKnowledgeEngine } from './beaconEngine';
import { getKnowledgeSources, getKnowledgeStats } from './knowledgeBase';
import { messages } from '../i18n/messages';

describe('beaconEngine', () => {
  beforeAll(async () => {
    await warmKnowledgeEngine();
  });

  it('uses authoritative direct hits for panic categories', () => {
    const response = inferTriageResponse({
      userText: '我被困在火场，有浓烟',
      categoryHint: '火场被困',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-fire',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(response.guidanceMode).toBe('grounded');
    expect(response.evidence.authoritative[0]?.source).toContain('Ready.gov');
  });

  it('uses lexical retrieval for emergent phrases without shortcut category', () => {
    const response = inferTriageResponse({
      userText: '被毒蛇咬了，腿开始肿，怎么处理',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-snake',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(response.evidence.authoritative.some((item) => item.title.includes('蛇咬伤') || item.title.includes('Snakebites'))).toBe(true);
    expect(response.steps.length).toBeGreaterThan(0);
  });

  it('prioritizes NPS field guidance for no-signal and nightfall wilderness queries', () => {
    const response = inferTriageResponse({
      userText: '山里没信号，天快黑了，我该怎么保命',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-wilderness-night',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(response.evidence.authoritative.some((item) => item.source.includes('National Park Service'))).toBe(true);
  });

  it('routes generic forest context to wilderness guidance instead of unrelated disease pages', () => {
    const response = inferTriageResponse({
      userText: '我在森林里面',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-forest-context',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(
      response.evidence.authoritative.some((item) =>
        /National Park Service|US Army FM 21-76/i.test(`${item.source} ${item.title}`),
      ),
    ).toBe(true);
    expect(
      response.evidence.authoritative.every((item) =>
        !/tick-borne encephalitis|relapsing fever|venomous spiders|venomous snakes/i.test(
          `${item.source} ${item.title}`,
        ),
      ),
    ).toBe(true);
  });

  it('routes ridge lightning questions to NWS safety guidance', () => {
    const response = inferTriageResponse({
      userText: '打雷时我还在山脊上，应该怎么办',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-lightning-ridge',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(response.evidence.authoritative.some((item) => item.source.includes('National Weather Service / NOAA'))).toBe(true);
  });

  it('routes tick bite questions to CDC outdoor hazard guidance', () => {
    const response = inferTriageResponse({
      userText: '被蜱虫咬了怎么办，要不要硬拔',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-tick',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(response.evidence.authoritative.some((item) => item.source.includes('CDC'))).toBe(true);
  });

  it('maps colloquial chest-pain queries to cardiac first-aid evidence', () => {
    const response = inferTriageResponse({
      userText: '胸口很痛还冒冷汗，左臂也痛，怎么先保命',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-chest-pain',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(
      response.evidence.authoritative.some((item) => /heart attack|心梗|心肌梗死|cardiac|心脏/i.test(`${item.title} ${item.source}`)),
    ).toBe(true);
  });

  it('maps scald and burn queries to burn-care evidence instead of unrelated injuries', () => {
    const response = inferTriageResponse({
      userText: '热油烫到手臂一大片，现在该怎么处理',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-burns',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(
      response.evidence.authoritative.some((item) => /burn|烧伤|燒傷|烫伤|燙傷|scald/i.test(`${item.title} ${item.source}`)),
    ).toBe(true);
  });

  it('routes radiation fallout questions to crisis guidance instead of generic medical content', () => {
    const response = inferTriageResponse({
      userText: '核爆后应该先做什么，外面可能有放射性灰尘',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-radiation',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(response.evidence.authoritative.some((item) => item.source.includes('Ready.gov') || item.source.includes('CDC'))).toBe(true);
  });

  it('routes cyberattack and outage questions to civil-defense tech guidance', () => {
    const response = inferTriageResponse({
      userText: '如果遇到AI攻击导致停电断网，我现在先做什么',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-cyber',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(response.evidence.authoritative.some((item) => item.source.includes('Ready.gov'))).toBe(true);
  });

  it('still returns AI guidance when evidence stays weak', () => {
    const response = inferTriageResponse({
      userText: 'qzmtvx blorf narpel zeek',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-limited',
    });

    expect(response.isKnowledgeBacked).toBe(false);
    expect(response.guidanceMode).toBe('grounded');
    expect(response.summary).not.toContain('AI 已介入分析');
    expect(response.steps.length).toBeGreaterThan(0);
  });

  it('keeps broad forest prompts grounded in field survival actions', () => {
    const response = inferTriageResponse({
      userText: '我在树林里，周围都是树',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-forest-fallback-shape',
    });

    expect(response.isKnowledgeBacked).toBe(true);
    expect(`${response.summary} ${response.steps.join(' ')}`).toMatch(/保温|发信号|不要.*乱走|更容易被找到|天黑|侦察/);
  });

  it('expands Chinese emergency terms to reach English authority pages and inject richer grounding steps', () => {
    const evidence = retrieveEvidenceBundle({
      userText: '怀疑铅中毒，最近接触了脱落油漆后开始头痛恶心。',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-lead',
    });

    expect(evidence.queryTerms).toContain('lead poisoning');

    const grounding = buildGroundingContext(evidence);
    expect(grounding).toContain('- ');
    expect(grounding).not.toContain('Do:');
    expect(grounding).not.toContain('Help:');
    expect(grounding).not.toContain('Source 1:');
  });

  it('keeps grounding compact enough for fast on-device prompts', () => {
    const evidence = retrieveEvidenceBundle({
      userText: '山里迷路了，天快黑了，没有信号，还担心打雷和失温。',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-compact-grounding',
    });

    const grounding = buildGroundingContext(evidence);
    expect(grounding.length).toBeLessThanOrEqual(860);
    expect(grounding).toContain('- ');
    expect(grounding).not.toContain('Categories:');
  });

  it('keeps generic forest grounding focused on the most relevant survival sources', () => {
    const evidence = retrieveEvidenceBundle({
      userText: '我在森林里面',
      categoryHint: '迷路断联',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-focused-grounding',
    });

    const grounding = buildGroundingContext(evidence);
    expect(grounding).toMatch(/保温|更容易被找到|盲目赶路|原地待援/);
    expect(grounding).not.toContain('热射病');
    expect(grounding).not.toContain('山洪');
  });

  it('does not feed weak supporting junk into grounding when no authoritative hit exists', () => {
    const grounding = buildGroundingContext({
      authoritative: [],
      supporting: [
        {
          id: 'weak-support',
          sourceId: 'weak-support',
          title: 'Random weak page',
          source: 'Weak Source',
          summary: 'Laptop course tablet enrollment copy that is not actionable.',
          steps: ['Start your course immediately.'],
          contraindications: [],
          escalation: '',
          strategy: 'lexical',
          score: 18,
        },
      ],
      matchedCategories: [],
      queryTerms: ['forest'],
    });

    expect(grounding).toBe('');
  });

  it('keeps lost quick-action grounding away from unrelated outdoor hazard cards', () => {
    const evidence = retrieveEvidenceBundle({
      userText: '我迷路断联了，需要立刻自救。',
      categoryHint: '迷路断联',
      powerMode: 'normal',
      locale: 'zh-CN',
      sessionId: 'session-engine-lost-quickaction-grounding',
    });

    const grounding = buildGroundingContext(evidence);
    expect(grounding).toMatch(/保温|发信号|天黑|原地待援|盲目赶路/);
    expect(grounding).not.toContain('热射病');
    expect(grounding).not.toContain('蜱虫');
    expect(grounding).not.toContain('蜘蛛');
    expect(grounding).not.toContain('雷暴');
  });

  it('keeps English lost quick actions anchored to curated survival evidence', () => {
    const evidence = retrieveEvidenceBundle({
      userText: messages.en['panic.lost.text'] ?? 'I am lost in the forest with no signal.',
      categoryHint: messages.en['panic.lost.label'],
      powerMode: 'normal',
      locale: 'en',
      sessionId: 'session-engine-en-lost-quickaction',
    });

    const grounding = buildGroundingContext(evidence);
    expect(
      evidence.authoritative.some((item) =>
        /National Park Service|US Army FM 21-76/i.test(`${item.source} ${item.title}`),
      ),
    ).toBe(true);
    expect(evidence.matchedCategories).toContain('迷路断联');
    expect(grounding).not.toMatch(/glacier|encephalitis|relapsing fever/i);
  });

  it('keeps English fire quick actions focused on fire survival instead of unrelated medical chunks', () => {
    const evidence = retrieveEvidenceBundle({
      userText: messages.en['panic.fire.text'] ?? 'I am trapped in fire and smoke.',
      categoryHint: messages.en['panic.fire.label'],
      powerMode: 'normal',
      locale: 'en',
      sessionId: 'session-engine-en-fire-quickaction',
    });

    const grounding = buildGroundingContext(evidence);
    expect(
      evidence.authoritative.some((item) => /Ready\.gov|Wildfires|烟雾围困|wildfire/i.test(`${item.source} ${item.title}`)),
    ).toBe(true);
    expect(grounding).not.toMatch(/overdose|poisoning|medication/i);
  });

  it('normalizes French quick-action labels to the same lost-survival retrieval path', () => {
    const evidence = retrieveEvidenceBundle({
      userText: messages.fr['panic.lost.text'] ?? 'Je suis perdu sans signal.',
      categoryHint: messages.fr['panic.lost.label'],
      powerMode: 'normal',
      locale: 'fr',
      sessionId: 'session-engine-fr-lost-quickaction',
    });

    expect(
      evidence.authoritative.some((item) =>
        /National Park Service|US Army FM 21-76/i.test(`${item.source} ${item.title}`),
      ),
    ).toBe(true);
    expect(evidence.matchedCategories).toContain('迷路断联');
  });

  it('normalizes Arabic trauma quick-action labels to the same bleeding guidance cluster', () => {
    const evidence = retrieveEvidenceBundle({
      userText: messages.ar['panic.trauma.text'] ?? 'إصابة شديدة ونزيف.',
      categoryHint: messages.ar['panic.trauma.label'],
      powerMode: 'normal',
      locale: 'ar',
      sessionId: 'session-engine-ar-trauma-quickaction',
    });

    expect(
      evidence.authoritative.some((item) =>
        /bleeding|tourniquet|止血|大出血|wound packing/i.test(`${item.title} ${item.source}`),
      ),
    ).toBe(true);
    expect(evidence.matchedCategories).toContain('致命外伤');
  });

  it('ships a real offline knowledge bundle instead of demo-sized cards', () => {
    const stats = getKnowledgeStats();
    const sources = getKnowledgeSources();
    expect(stats.sourceCount).toBeGreaterThanOrEqual(2600);
    expect(stats.entryCount).toBeGreaterThanOrEqual(6800);
    expect(sources.some((source) => source.id === 'fm-21-76-survival')).toBe(true);
    expect(sources.some((source) => source.id.startsWith('merck-'))).toBe(true);
    expect(sources.some((source) => source.id.startsWith('cdc-az-'))).toBe(true);
    expect(sources.some((source) => source.id === 'redcross-tourniquet')).toBe(true);
    expect(sources.some((source) => source.id === 'niddk-hypoglycemia')).toBe(true);
    expect(sources.some((source) => source.id === 'nps-trip-planning-guide')).toBe(true);
    expect(sources.some((source) => source.id === 'nws-lightning-safety')).toBe(true);
    expect(sources.some((source) => source.id === 'ready-radiation-emergencies')).toBe(true);
  });
});
