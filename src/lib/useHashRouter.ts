import { useState, useEffect, useCallback } from 'react';

export function useHashRouter() {
  const [hash, setHash] = useState(() => window.location.hash || '#/');

  useEffect(() => {
    const handler = () => setHash(window.location.hash || '#/');
    window.addEventListener('hashchange', handler);
    return () => window.removeEventListener('hashchange', handler);
  }, []);

  const navigate = useCallback((newHash: string, replace = false) => {
    if (replace) {
      window.history.replaceState(null, '', newHash);
      setHash(newHash);
    } else {
      window.location.hash = newHash;
    }
  }, []);

  const goBack = useCallback((fallbackHash = '#/') => {
    if (window.history.length > 1) {
      window.history.back();
    } else {
      navigate(fallbackHash, true);
    }
  }, [navigate]);

  return { hash, navigate, goBack };
}
