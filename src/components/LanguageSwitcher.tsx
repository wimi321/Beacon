import { Check, ChevronDown, Globe } from 'lucide-react';
import { useEffect, useMemo, useRef, useState } from 'react';
import { useI18n } from '../i18n';
import { SUPPORTED_LANGUAGES, LanguageCode } from '../i18n/languages';

export function LanguageSwitcher() {
  const { locale, setLocale, t } = useI18n();
  const [isOpen, setIsOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement | null>(null);
  const currentLanguage = useMemo(
    () => SUPPORTED_LANGUAGES.find((lang) => lang.code === locale) ?? SUPPORTED_LANGUAGES[0],
    [locale],
  );

  useEffect(() => {
    if (!isOpen) {
      return undefined;
    }

    function handlePointerDown(event: MouseEvent | TouchEvent) {
      const target = event.target;
      if (target instanceof Node && rootRef.current?.contains(target)) {
        return;
      }
      setIsOpen(false);
    }

    function handleKeyDown(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        setIsOpen(false);
      }
    }

    document.addEventListener('mousedown', handlePointerDown);
    document.addEventListener('touchstart', handlePointerDown);
    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('mousedown', handlePointerDown);
      document.removeEventListener('touchstart', handlePointerDown);
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [isOpen]);

  function chooseLanguage(code: LanguageCode): void {
    setLocale(code);
    setIsOpen(false);
  }

  return (
    <div className="language-switcher" ref={rootRef}>
      <button
        type="button"
        className="language-trigger"
        aria-label={t('language.selection')}
        aria-haspopup="listbox"
        aria-expanded={isOpen}
        onClick={() => setIsOpen((value) => !value)}
      >
        <Globe size={14} aria-hidden="true" />
        <span>{currentLanguage.nativeName}</span>
        <ChevronDown size={13} aria-hidden="true" className={isOpen ? 'open' : ''} />
      </button>

      {isOpen && (
        <div className="language-menu" role="listbox" aria-label={t('language.selection')}>
          {SUPPORTED_LANGUAGES.map((lang) => (
            <button
              key={lang.code}
              type="button"
              role="option"
              aria-selected={lang.code === locale}
              className={`language-option ${lang.code === locale ? 'selected' : ''}`}
              onClick={() => chooseLanguage(lang.code)}
            >
              <span className="language-option-main">{lang.nativeName}</span>
              <span className="language-option-sub">{lang.name}</span>
              {lang.code === locale && <Check size={14} aria-hidden="true" />}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
