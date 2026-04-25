import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import { LanguageSwitcher } from './LanguageSwitcher';
import { I18nProvider } from '../i18n';
import { SUPPORTED_LANGUAGES } from '../i18n/languages';

function renderLanguageSwitcher() {
  window.localStorage.setItem('beacon_locale', 'en');
  return render(
    <I18nProvider>
      <LanguageSwitcher />
    </I18nProvider>,
  );
}

describe('LanguageSwitcher', () => {
  it('opens a custom language list with all supported languages', () => {
    renderLanguageSwitcher();

    fireEvent.click(screen.getByRole('button', { name: 'Language selection' }));

    const options = screen.getAllByRole('option');
    expect(options).toHaveLength(SUPPORTED_LANGUAGES.length);
  });

  it('has correct aria-label', () => {
    renderLanguageSwitcher();

    expect(screen.getByLabelText('Language selection')).toBeInTheDocument();
  });

  it('each option shows native language name', () => {
    renderLanguageSwitcher();

    fireEvent.click(screen.getByRole('button', { name: 'Language selection' }));

    for (const lang of SUPPORTED_LANGUAGES) {
      expect(screen.getAllByText(lang.nativeName).length).toBeGreaterThan(0);
    }
  });
});
