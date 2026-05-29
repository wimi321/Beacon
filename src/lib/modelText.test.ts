import { describe, expect, it } from 'vitest';
import type { TriageResponse } from './types';
import {
  buildDisplayResponseText,
  formatModelTextForDisplay,
  processModelResponse,
  splitModelResponseText,
} from './modelText';

function createResponse(overrides?: Partial<TriageResponse>): TriageResponse {
  return {
    summary: 'Stay calm.',
    steps: [],
    disclaimer: '',
    isKnowledgeBacked: false,
    guidanceMode: 'grounded',
    evidence: {
      authoritative: [],
      supporting: [],
      matchedCategories: [],
      queryTerms: [],
    },
    usedProfileName: 'Gemma 4 E2B',
    ...overrides,
  };
}

describe('processModelResponse', () => {
  it('only restores escaped newlines and strips control chars', () => {
    expect(processModelResponse('Line 1\\n\\n1. Step one\u0007')).toBe('Line 1\n\n1. Step one');
  });

  it('strips structural prompt markers echoed by the model', () => {
    const raw = '--- BEGIN USER MESSAGE ---\n被蛇咬了\n--- END USER MESSAGE ---\n不要切开伤口。';
    expect(processModelResponse(raw)).toBe('被蛇咬了\n不要切开伤口。');
  });

  it('strips evidence markers echoed by the model', () => {
    const raw = '--- BEGIN EVIDENCE ---\nFM 21-76\n--- END EVIDENCE ---\nStay calm.';
    expect(processModelResponse(raw)).toBe('FM 21-76\nStay calm.');
  });
});

describe('formatModelTextForDisplay', () => {
  it('removes lightweight emphasis markers without flattening structure', () => {
    expect(formatModelTextForDisplay('*Keep warm*\n\n1. Find shelter')).toBe(
      'Keep warm\n\n1. Find shelter',
    );
  });

  it('promotes inline numbered guidance into readable markdown blocks', () => {
    expect(
      formatModelTextForDisplay(
        '根据以下步骤进行自救：1. **评估状况：**停下，评估伤情。2. **选择位置：**优先背风位置。**核心原则：**先停、想、看、计划。',
      ),
    ).toBe(
      '根据以下步骤进行自救：\n\n1. 评估状况： 停下，评估伤情。\n\n2. 选择位置： 优先背风位置。\n\n核心原则： 先停、想、看、计划。',
    );
  });

  it('keeps readable bullets while stripping orphan emphasis stars from model output', () => {
    expect(
      formatModelTextForDisplay(
        '至少应携带以下装备： *导航工具、头灯或手电。\n* 保暖防雨层。\n- 急救包。 *足够饮水和高热量食物。',
      ),
    ).toBe(
      '至少应携带以下装备： 导航工具、头灯或手电。\n- 保暖防雨层。\n- 急救包。 足够饮水和高热量食物。',
    );
  });

  it('keeps mixed bullet and numbered survival guidance as real markdown blocks', () => {
    expect(
      formatModelTextForDisplay(
        '4. 优先保障基本生存：立即优先建立以下三件事： • 保温。 • 饮水。 • 求救信号。 5. 谨慎行动：不要盲目赶路。 6. 规避危险地形：不要穿越陡坡。',
      ),
    ).toBe(
      [
        '4. 优先保障基本生存：立即优先建立以下三件事：',
        '',
        '- 保温。',
        '',
        '- 饮水。',
        '',
        '- 求救信号。',
        '',
        '5. 谨慎行动：不要盲目赶路。',
        '',
        '6. 规避危险地形：不要穿越陡坡。',
      ].join('\n'),
    );
  });

  it('removes orphan trailing numbered-list markers from interrupted generation', () => {
    expect(
      formatModelTextForDisplay(
        '4. 优先保障生存：优先建立保温、饮水、求救信号这三件事，然后再考虑短距离侦察。 5',
      ),
    ).toBe(
      '4. 优先保障生存：优先建立保温、饮水、求救信号这三件事，然后再考虑短距离侦察。',
    );
  });

  it('removes standalone trailing numbered-list markers before markdown rendering', () => {
    expect(
      formatModelTextForDisplay(
        '1. 停下来。\n2. 保暖。\n3. 发信号。\n4. 等待救援。\n5',
      ),
    ).toBe('1. 停下来。\n2. 保暖。\n3. 发信号。\n4. 等待救援。');
  });

  it('removes a final incomplete block caused by output-token truncation', () => {
    expect(
      formatModelTextForDisplay(
        '第一步：停下来，冷静思考。\n\n1. 自我评估：检查受伤和失温。\n\n第二步：优先处理生存需求。\n\n1. 保温：建立一个临时庇护所，防止体',
      ),
    ).toBe(
      '第一步：停下来，冷静思考。\n\n1. 自我评估：检查受伤和失温。\n\n第二步：优先处理生存需求。',
    );
  });
});

describe('splitModelResponseText', () => {
  it('keeps a simple compatibility split for summary and steps', () => {
    const parsed = splitModelResponseText('Stay where you are.\\n1. Make yourself visible\\n2. Keep warm');

    expect(parsed.summary).toBe('Stay where you are.');
    expect(parsed.steps).toEqual(['1. Make yourself visible', '2. Keep warm']);
  });
});

describe('buildDisplayResponseText', () => {
  it('prefers raw response text when native provides it', () => {
    const response = createResponse({
      summary: 'Fallback summary',
      steps: ['Fallback step'],
    }) as TriageResponse & { rawText?: string };
    response.rawText = 'Stay calm.\\n\\n1. Find shelter';

    expect(buildDisplayResponseText(response)).toBe('Stay calm.\n\n1. Find shelter');
  });
});
