import { Globe } from 'lucide-react';
import { useI18n } from '../i18n';
import { SUPPORTED_LANGUAGES, LanguageCode } from '../i18n/languages';

export function LanguageSwitcher() {
  const { locale, setLocale, t } = useI18n();

  return (
    <div className="language-switcher" style={{ position: 'relative', display: 'inline-block' }}>
      <select
        aria-label={t('language.selection')}
        title={t('language.selection')}
        value={locale}
        onChange={(e) => setLocale(e.target.value as LanguageCode)}
        style={{
          appearance: 'none',
          backgroundColor: 'rgba(255, 255, 255, 0.05)',
          color: 'var(--text-secondary)',
          border: '1px solid rgba(255, 255, 255, 0.1)',
          borderRadius: '999px',
          paddingBlock: '4px',
          paddingInlineStart: '12px',
          paddingInlineEnd: '28px',
          fontSize: '12px',
          fontWeight: '600',
          cursor: 'pointer',
          outline: 'none',
        }}
      >
        {SUPPORTED_LANGUAGES.map((lang) => (
          <option key={lang.code} value={lang.code} style={{ color: '#000' }}>
            {lang.nativeName}
          </option>
        ))}
      </select>
      <Globe
        size={12}
        style={{
          position: 'absolute',
          insetInlineEnd: '8px',
          top: '50%',
          transform: 'translateY(-50%)',
          pointerEvents: 'none',
          color: 'var(--text-secondary)',
        }}
      />
    </div>
  );
}
