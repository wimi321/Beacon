import { render, screen, act } from '@testing-library/react';
import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { I18nProvider, useI18n } from './index';
import { SUPPORTED_LANGUAGES } from './languages';
import { messages } from './messages';

function TestComponent() {
  const { t, locale, setLocale } = useI18n();
  return (
    <div>
      <span data-testid="current-locale">{locale}</span>
      <span data-testid="translated-title">{t('header.title')}</span>
      <span data-testid="translated-unknown">{t('hero.kicker' as any)}</span>
      <button onClick={() => setLocale('zh-CN')}>Switch CN</button>
      <button onClick={() => setLocale('ja')}>Switch JA</button>
      <button onClick={() => setLocale('ar')}>Switch AR</button>
    </div>
  );
}

const mockStorage: Record<string, string> = {};
const mockLocalStorage = {
  getItem: vi.fn((k: string) => mockStorage[k] || null),
  setItem: vi.fn((k: string, v: string) => { mockStorage[k] = v; }),
  clear: vi.fn(() => { Object.keys(mockStorage).forEach((k) => delete mockStorage[k]); }),
};
vi.stubGlobal('localStorage', mockLocalStorage);

describe('i18n Module', () => {
  beforeEach(() => {
    localStorage.clear();
    Object.defineProperty(window.navigator, 'languages', {
      value: ['en-US', 'en'],
      configurable: true,
    });
  });

  afterEach(() => {
    localStorage.clear();
  });

  it('detects default language and falls back to en', () => {
    render(
      <I18nProvider>
        <TestComponent />
      </I18nProvider>
    );
    expect(screen.getByTestId('current-locale').textContent).toBe('en');
    expect(screen.getByTestId('translated-title').textContent).toBe('Beacon Node');
  });

  it('prefers localStorage over navigator', () => {
    localStorage.setItem('beacon_locale', 'ko');
    render(
      <I18nProvider>
        <TestComponent />
      </I18nProvider>
    );
    expect(screen.getByTestId('current-locale').textContent).toBe('ko');
    expect(screen.getByTestId('translated-title').textContent).toBe('Beacon 노드');
  });

  it('can manually switch language and persist to storage', () => {
    render(
      <I18nProvider>
        <TestComponent />
      </I18nProvider>
    );
    
    const btn = screen.getByText('Switch CN');
    act(() => {
      btn.click();
    });

    expect(screen.getByTestId('current-locale').textContent).toBe('zh-CN');
    expect(screen.getByTestId('translated-title').textContent).toBe('Beacon 节点');
    expect(localStorage.getItem('beacon_locale')).toBe('zh-CN');
  });

  it('changes document direction when switching to RTL', () => {
    render(
      <I18nProvider>
        <TestComponent />
      </I18nProvider>
    );

    const btn = screen.getByText('Switch AR');
    act(() => {
      btn.click();
    });

    expect(screen.getByTestId('current-locale').textContent).toBe('ar');
    expect(document.documentElement.dir).toBe('rtl');
  });

  it('uses locale strings when available', () => {
    render(
      <I18nProvider>
        <TestComponent />
      </I18nProvider>
    );

    const btn = screen.getByText('Switch AR');
    act(() => {
      btn.click();
    });
    
    expect(screen.getByTestId('translated-unknown').textContent).toBe('لا شبكة، بطارية منخفضة، ظروف قاسية');
  });

  it('maps regional Chinese locales to the supported locale set', () => {
    Object.defineProperty(window.navigator, 'languages', {
      value: ['zh-HK'],
      configurable: true,
    });

    render(
      <I18nProvider>
        <TestComponent />
      </I18nProvider>
    );

    expect(screen.getByTestId('current-locale').textContent).toBe('zh-TW');
  });

  it('keeps every supported locale complete for visible UI keys', () => {
    const englishKeys = Object.keys(messages.en);

    for (const language of SUPPORTED_LANGUAGES) {
      const localeMessages = messages[language.code];
      const missing = englishKeys.filter((key) => !(key in localeMessages));
      expect(missing, `${language.code} is missing translations`).toEqual([]);
    }
  });
});
