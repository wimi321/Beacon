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
});

describe('formatModelTextForDisplay', () => {
  it('preserves markdown syntax instead of rewriting it', () => {
    expect(formatModelTextForDisplay('*Keep warm*\n\n1. Find shelter')).toBe(
      '*Keep warm*\n\n1. Find shelter',
    );
  });

  it('promotes inline numbered guidance into readable markdown blocks', () => {
    expect(
      formatModelTextForDisplay(
        '根据以下步骤进行自救：1. **评估状况：**停下，评估伤情。2. **选择位置：**优先背风位置。**核心原则：**先停、想、看、计划。',
      ),
    ).toBe(
      '根据以下步骤进行自救：\n\n1. **评估状况：** 停下，评估伤情。\n2. **选择位置：** 优先背风位置。\n\n**核心原则：** 先停、想、看、计划。',
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
