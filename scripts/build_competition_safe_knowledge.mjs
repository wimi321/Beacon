#!/usr/bin/env node
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const sourcePath = path.join(root, 'public/knowledge/offline_knowledge.json');
const outputPath = path.join(root, 'public/knowledge/offline_knowledge.competition-safe.json');

const blockedAuthorities = new Map([
  ['MSD Manual', 'permission required for bundled full-text/RAG use'],
  ['Merck Manual Professional Edition', 'permission required for bundled full-text/RAG use'],
  ['MedlinePlus', 'raw pages can include restrictive AI/indexing terms'],
  ['HuggingFace', 'dataset license must be verified before competition use'],
  ['American Red Cross', 'content reuse terms need review before bundling'],
  ['NHS', 'Crown copyright/API/content terms need review before bundling'],
  ['WHO', 'publication-specific license review required before bundling'],
]);

const knowledge = JSON.parse(readFileSync(sourcePath, 'utf8'));
const sources = knowledge.sources ?? [];
const entries = knowledge.entries ?? [];

const blockedSourceIds = new Set(
  sources
    .filter((source) => blockedAuthorities.has(source.authority || ''))
    .map((source) => source.id),
);

const safeSources = sources.filter((source) => !blockedSourceIds.has(source.id));
const safeSourceIds = new Set(safeSources.map((source) => source.id));
const safeEntries = entries.filter((entry) => safeSourceIds.has(entry.sourceId));

const countByAuthority = (items) => {
  const counts = new Map();
  for (const item of items) {
    const authority = item.authority || 'Unknown';
    counts.set(authority, (counts.get(authority) ?? 0) + 1);
  }
  return [...counts.entries()].sort((a, b) => b[1] - a[1]);
};

const summary = {
  generatedAt: new Date().toISOString(),
  input: {
    sources: sources.length,
    entries: entries.length,
  },
  safeProfile: {
    sources: safeSources.length,
    entries: safeEntries.length,
    removedSources: sources.length - safeSources.length,
    removedEntries: entries.length - safeEntries.length,
    blockedAuthorities: [...blockedAuthorities.entries()].map(([authority, reason]) => ({ authority, reason })),
    topAuthorities: countByAuthority(safeSources).slice(0, 20).map(([authority, count]) => ({ authority, count })),
  },
};

console.log('# Beacon Competition-Safe Knowledge Profile');
console.log('');
console.log(`- Input sources: ${summary.input.sources}`);
console.log(`- Input entries: ${summary.input.entries}`);
console.log(`- Safe sources: ${summary.safeProfile.sources}`);
console.log(`- Safe entries: ${summary.safeProfile.entries}`);
console.log(`- Removed sources: ${summary.safeProfile.removedSources}`);
console.log(`- Removed entries: ${summary.safeProfile.removedEntries}`);
console.log('');
console.log('## Top safe authorities');
for (const item of summary.safeProfile.topAuthorities) {
  console.log(`- ${item.authority}: ${item.count}`);
}
console.log('');
console.log('## Blocked authorities');
for (const item of summary.safeProfile.blockedAuthorities) {
  console.log(`- ${item.authority}: ${item.reason}`);
}

if (process.argv.includes('--write')) {
  const output = {
    ...knowledge,
    generatedAt: summary.generatedAt,
    profile: 'competition-safe',
    sources: safeSources,
    entries: safeEntries,
  };
  mkdirSync(path.dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, `${JSON.stringify(output)}\n`);
  console.log('');
  console.log(`Wrote ${path.relative(root, outputPath)}`);
}
