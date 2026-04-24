import { ArrowLeft } from 'lucide-react';
import { useI18n } from '../i18n';
import { LanguageSwitcher } from './LanguageSwitcher';

interface NavBarProps {
  showBack?: boolean;
  onBack?: () => void;
  onStatusClick?: () => void;
  title?: string;
  sosActive?: boolean;
  nodesCount?: number;
  statusLine?: string;
  isOnline?: boolean;
}

export function NavBar({ showBack, onBack, onStatusClick, title, sosActive, nodesCount, statusLine, isOnline }: NavBarProps) {
  const { t } = useI18n();
  const statusText = sosActive
    ? `📡 ${t('status.broadcasting', { count: nodesCount || 0 })}`
    : `${statusLine === t('status.offline_ready') ? '🔋 ' : ''}${statusLine}`;
  const statusClassName = `status-badge ${sosActive ? 'offline' : ''} ${isOnline === false ? 'network-offline' : ''}`;

  return (
    <header className={`header ${showBack ? 'header-chat' : 'header-home'}`}>
      {showBack && (
        <div className="header-main">
          <div className="header-side">
            <button
              onClick={onBack}
              className="nav-back-btn"
              aria-label={t('action.clear_chat') || 'Go back'}
              type="button"
            >
              <ArrowLeft
                size={24}
                style={{ transform: document.documentElement.dir === 'rtl' ? 'rotate(180deg)' : 'none' }}
              />
            </button>
          </div>
          <div className="header-title">
            <span>{title || t('header.title')}</span>
          </div>
          <div className="header-side header-side-placeholder" aria-hidden="true" />
        </div>
      )}

      {!showBack && (
        <div className="header-meta">
          <LanguageSwitcher />
          {onStatusClick ? (
            <button
              className={statusClassName}
              type="button"
              onClick={onStatusClick}
              aria-label={`${t('model.status')}: ${statusText}`}
              title={t('model.manage')}
            >
              {isOnline === false && <span aria-label={t('status.network_offline')}>📴 </span>}
              {statusText}
            </button>
          ) : (
            <div className={statusClassName}>
              {isOnline === false && <span aria-label={t('status.network_offline')}>📴 </span>}
              {statusText}
            </div>
          )}
        </div>
      )}
    </header>
  );
}
