import { SUPPORTED_LANGUAGES, type LanguageCode } from './languages';
import { messages, type TranslationKey } from './messages';

const SUPPORTED_LANGUAGE_CODES = new Set<LanguageCode>(
  SUPPORTED_LANGUAGES.map((language) => language.code),
);

const LOCALE_ALIASES: Record<string, LanguageCode> = {
  zh: 'zh-CN',
  'zh-cn': 'zh-CN',
  'zh-sg': 'zh-CN',
  'zh-tw': 'zh-TW',
  'zh-hk': 'zh-TW',
  'zh-mo': 'zh-TW',
};

export function resolveLocaleCode(locale?: string): LanguageCode {
  const raw = locale?.trim();
  if (!raw) {
    return 'en';
  }

  if (SUPPORTED_LANGUAGE_CODES.has(raw as LanguageCode)) {
    return raw as LanguageCode;
  }

  const normalized = raw.toLowerCase();
  const aliased = LOCALE_ALIASES[normalized];
  if (aliased) {
    return aliased;
  }

  const prefix = normalized.split('-')[0];
  if (SUPPORTED_LANGUAGE_CODES.has(prefix as LanguageCode)) {
    return prefix as LanguageCode;
  }

  return 'en';
}

export function translateMessage(
  locale: string | undefined,
  key: TranslationKey,
  params?: Record<string, string | number>,
): string {
  const resolvedLocale = resolveLocaleCode(locale);
  const template = messages[resolvedLocale]?.[key] ?? messages.en[key] ?? key;

  if (!params) {
    return template;
  }

  return Object.entries(params).reduce(
    (value, [paramKey, paramValue]) => value.replace(new RegExp(`\\{${paramKey}\\}`, 'g'), String(paramValue)),
    template,
  );
}
