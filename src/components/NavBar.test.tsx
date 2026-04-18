import { fireEvent, render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { NavBar } from './NavBar';
import { I18nProvider } from '../i18n';

function renderNavBar(props: Parameters<typeof NavBar>[0] = {}) {
  window.localStorage.setItem('beacon_locale', 'en');
  return render(
    <I18nProvider>
      <NavBar {...props} />
    </I18nProvider>,
  );
}

describe('NavBar', () => {
  it('renders status badge with statusLine when showBack=false (home view)', () => {
    renderNavBar({ showBack: false, statusLine: 'Offline Ready' });

    expect(screen.getByText(/Offline Ready/)).toBeInTheDocument();
  });

  it('renders back button and title when showBack=true (chat view)', () => {
    renderNavBar({ showBack: true, title: 'Fire Rescue' });

    expect(screen.getByRole('button', { name: /Return Home/i })).toBeInTheDocument();
    expect(screen.getByText('Fire Rescue')).toBeInTheDocument();
  });

  it('fires onBack callback when back button is clicked', () => {
    const onBack = vi.fn();
    renderNavBar({ showBack: true, onBack });

    fireEvent.click(screen.getByRole('button', { name: /Return Home/i }));

    expect(onBack).toHaveBeenCalledTimes(1);
  });

  it('shows offline indicator when isOnline=false', () => {
    renderNavBar({ showBack: false, isOnline: false, statusLine: 'Offline Ready' });

    expect(screen.getByLabelText('No network')).toBeInTheDocument();
  });

  it('does NOT show offline indicator when isOnline=true', () => {
    renderNavBar({ showBack: false, isOnline: true, statusLine: 'Offline Ready' });

    expect(screen.queryByLabelText('No network')).toBeNull();
  });

  it('shows SOS broadcasting message when sosActive=true', () => {
    renderNavBar({ showBack: false, sosActive: true, nodesCount: 3 });

    expect(screen.getByText(/Broadcasting \(3 peers\)/)).toBeInTheDocument();
  });

  it('shows battery emoji prefix when statusLine matches offline_ready', () => {
    const { container } = renderNavBar({ showBack: false, statusLine: 'Offline Ready' });

    const badge = container.querySelector('.status-badge');
    expect(badge).not.toBeNull();
    expect(badge!.textContent).toContain('\uD83D\uDD0B');
  });
});
