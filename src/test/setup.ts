import { cleanup } from '@testing-library/react';
import { expect } from 'vitest';
import * as matchers from '@testing-library/jest-dom/matchers';
import { afterEach } from 'vitest';
import { readFile } from 'node:fs/promises';
import path from 'node:path';

const memoryStorage = (() => {
  const store = new Map<string, string>();
  return {
    getItem: (key: string) => store.get(key) ?? null,
    setItem: (key: string, value: string) => {
      store.set(key, value);
    },
    removeItem: (key: string) => {
      store.delete(key);
    },
    clear: () => {
      store.clear();
    },
  };
})();

Object.defineProperty(window, 'localStorage', {
  value: memoryStorage,
  writable: true,
});

const originalFetch = globalThis.fetch?.bind(globalThis);
globalThis.fetch = async (input: RequestInfo | URL, init?: RequestInit) => {
  const requestUrl = typeof input === 'string'
    ? input
    : input instanceof URL
      ? input.toString()
      : input.url;

  if (requestUrl.includes('knowledge/offline_knowledge.json')) {
    const filePath = path.join(process.cwd(), 'knowledge', 'offline_knowledge.json');
    const body = await readFile(filePath, 'utf8');
    return new Response(body, {
      status: 200,
      headers: {
        'Content-Type': 'application/json',
      },
    });
  }

  if (originalFetch) {
    return originalFetch(input, init);
  }

  throw new Error(`Unhandled fetch in test environment: ${requestUrl}`);
};

expect.extend(matchers);
afterEach(() => {
  cleanup();
  window.localStorage.clear();
});
