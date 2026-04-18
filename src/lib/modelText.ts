import type { TriageResponse } from './types';

const CONTROL_CHARS_REGEX = /[\u0000-\u0008\u000B\u000C\u000E-\u001F\u007F]/g;
const INLINE_NUMBERED_ITEM_REGEX = /([^\n])[ \t]+((?:[1-9]\d?)\.\s+(?=(?:\*\*|[A-Za-z\u00C0-\u024F\u0400-\u04FF\u0600-\u06FF\u0900-\u097F\u0E00-\u0E7F\u3040-\u30ff\u3400-\u9fff])))/gu;
const INLINE_BULLET_ITEM_REGEX = /([^\n])[ \t]+([*-]\s+(?=(?:\*\*|[A-Za-z\u00C0-\u024F\u0400-\u04FF\u0600-\u06FF\u0900-\u097F\u0E00-\u0E7F\u3040-\u30ff\u3400-\u9fff])))/gu;
const STRONG_LABEL_BODY = '[^\\n*.。！？!?]{0,24}[:：][^\\n*.。！？!?]{0,12}';
const INLINE_EMPHASIS_HEADING_REGEX = new RegExp(`([。！？!?；;])[ \\t]*(\\*\\*${STRONG_LABEL_BODY}\\*\\*)`, 'g');
const TIGHT_STRONG_LABEL_REGEX = new RegExp(`(\\*\\*${STRONG_LABEL_BODY}\\*\\*)(?=\\S)`, 'g');

type TriageResponseWithRawText = TriageResponse & { rawText?: string };

function extractRawResponseText(response: TriageResponse): string {
  const rawText = (response as TriageResponseWithRawText).rawText;
  return typeof rawText === 'string' ? rawText : '';
}

export function processModelResponse(value?: string | null): string {
  return (value ?? '')
    .replace(/\\n/g, '\n')
    .replace(/\r\n?/g, '\n')
    .replace(/\$\s*\\?l?rightarrow\s*\$/gi, ' -> ')
    .replace(CONTROL_CHARS_REGEX, '');
}

export function hasMeaningfulModelText(value?: string | null): boolean {
  return processModelResponse(value).trim().length > 0;
}

function softenInlineMarkdownStructure(value: string): string {
  return value
    .replace(/([:：])[ \t]*(1\.\s+)/g, '$1\n\n$2')
    .replace(/([。！？.!?；;])[ \t]*((?:[1-9]\d?)\.\s+)/g, '$1\n$2')
    .replace(/([:：])[ \t]*([*-]\s+)/g, '$1\n\n$2')
    .replace(/([。！？.!?；;])[ \t]*([*-]\s+)/g, '$1\n$2')
    .replace(INLINE_NUMBERED_ITEM_REGEX, '$1\n$2')
    .replace(INLINE_BULLET_ITEM_REGEX, '$1\n$2')
    .replace(INLINE_EMPHASIS_HEADING_REGEX, '$1\n\n$2')
    .replace(TIGHT_STRONG_LABEL_REGEX, '$1 ')
    .replace(/\n{3,}/g, '\n\n');
}

export function formatModelTextForDisplay(value?: string | null): string {
  return softenInlineMarkdownStructure(processModelResponse(value));
}

export function splitModelResponseText(text: string): { summary: string; steps: string[] } {
  const normalized = processModelResponse(text).trim();
  if (normalized.length === 0) {
    return {
      summary: 'No response returned from local model.',
      steps: [],
    };
  }

  const lines = normalized
    .split('\n')
    .map((line) => line.trim())
    .filter(Boolean);

  if (lines.length === 0) {
    return {
      summary: 'No response returned from local model.',
      steps: [],
    };
  }

  return {
    summary: lines[0] ?? 'No response returned from local model.',
    steps: lines.slice(1),
  };
}

export function buildDisplayResponseText(
  response: TriageResponse,
  streamedText?: string,
): string {
  const preferredText = extractRawResponseText(response);
  if (hasMeaningfulModelText(preferredText)) {
    return formatModelTextForDisplay(preferredText);
  }

  if (hasMeaningfulModelText(streamedText)) {
    return formatModelTextForDisplay(streamedText);
  }

  return formatModelTextForDisplay(
    [response.summary, ...response.steps]
      .filter((segment) => segment.trim().length > 0)
      .join('\n'),
  );
}
