#!/usr/bin/env node
import { readFileSync, existsSync } from 'node:fs';
import path from 'node:path';

const root = process.cwd();
const readJson = (relativePath) =>
  JSON.parse(readFileSync(path.join(root, relativePath), 'utf8'));

const exists = (relativePath) => existsSync(path.join(root, relativePath));

const packageJson = readJson('package.json');
const allowlist = readJson('public/model_allowlist.json');
const knowledge = readJson('public/knowledge/offline_knowledge.json');
const buildGradle = readFileSync(path.join(root, 'android/app/build.gradle'), 'utf8');

const sources = knowledge.sources ?? [];
const entries = knowledge.entries ?? [];

const authorityCounts = new Map();
for (const source of sources) {
  const authority = source.authority || 'Unknown';
  authorityCounts.set(authority, (authorityCounts.get(authority) ?? 0) + 1);
}

const riskyAuthorities = new Map([
  ['MSD Manual', 'high: remove from competition-safe build or document permission'],
  ['Merck Manual Professional Edition', 'high: remove from competition-safe build or document permission'],
  ['MedlinePlus', 'high: raw pages can include restrictive AI/indexing terms'],
  ['HuggingFace', 'review: dataset license must be verified'],
  ['American Red Cross', 'review: confirm content reuse terms'],
  ['NHS', 'review: confirm Crown copyright/API terms'],
  ['WHO', 'review: confirm publication-specific license'],
]);

const requiredDocs = [
  'docs/competition/README.md',
  'docs/competition/WRITEUP_DRAFT.md',
  'docs/competition/VIDEO_SCRIPT.md',
  'docs/competition/ARCHITECTURE.md',
  'docs/competition/VALIDATION.md',
  'docs/competition/DATA_LICENSES.md',
  'docs/competition/SUBMISSION_CHECKLIST.md',
];

const models = allowlist.models ?? [];
const mirrorProblems = models
  .map((model) => ({
    id: model.id,
    mirrors: model.downloadUrls?.length ?? (model.downloadUrl ? 1 : 0),
  }))
  .filter((model) => model.mirrors < 2);

const missingDocs = requiredDocs.filter((file) => !exists(file));
const runtimeOk = buildGradle.includes('com.google.ai.edge.litertlm:litertlm-android');
const versionMatch = buildGradle.includes(`versionName "${packageJson.version}"`);

const riskyPresent = [...riskyAuthorities.entries()]
  .map(([authority, status]) => ({
    authority,
    count: authorityCounts.get(authority) ?? 0,
    status,
  }))
  .filter((item) => item.count > 0);

const latestApk = 'android/app/build/outputs/apk/release/app-release.apk';

console.log('# Beacon Competition Readiness Audit');
console.log('');
console.log(`- Package version: ${packageJson.version}`);
console.log(`- Android versionName matches package: ${versionMatch ? 'yes' : 'no'}`);
console.log(`- LiteRT-LM Android dependency present: ${runtimeOk ? 'yes' : 'no'}`);
console.log(`- Knowledge sources: ${sources.length}`);
console.log(`- Knowledge entries: ${entries.length}`);
console.log(`- Models: ${models.map((model) => `${model.id} (${model.downloadUrls?.length ?? 0} mirrors)`).join(', ')}`);
console.log(`- Release APK present: ${exists(latestApk) ? latestApk : 'no'}`);
console.log('');

console.log('## Required Competition Docs');
if (missingDocs.length === 0) {
  console.log('- all required docs present');
} else {
  for (const file of missingDocs) {
    console.log(`- missing: ${file}`);
  }
}
console.log('');

console.log('## Model Download Mirrors');
if (mirrorProblems.length === 0) {
  console.log('- all listed models have at least two mirrors');
} else {
  for (const model of mirrorProblems) {
    console.log(`- ${model.id}: only ${model.mirrors} mirror(s)`);
  }
}
console.log('');

console.log('## Largest Knowledge Authorities');
for (const [authority, count] of [...authorityCounts.entries()].sort((a, b) => b[1] - a[1]).slice(0, 12)) {
  console.log(`- ${authority}: ${count}`);
}
console.log('');

console.log('## License Review Flags');
if (riskyPresent.length === 0) {
  console.log('- no configured high-risk authorities found');
} else {
  for (const item of riskyPresent) {
    console.log(`- ${item.authority}: ${item.count} source(s), ${item.status}`);
  }
}
console.log('');

const blockers = [
  ...missingDocs.map((file) => `missing competition doc: ${file}`),
  ...(runtimeOk ? [] : ['LiteRT-LM Android dependency not found']),
  ...(versionMatch ? [] : ['package.json and Android versionName differ']),
  ...mirrorProblems.map((model) => `${model.id} has fewer than two mirrors`),
];

console.log('## Submission Notes');
if (blockers.length === 0) {
  console.log('- engineering readiness checks passed');
} else {
  for (const blocker of blockers) {
    console.log(`- blocker: ${blocker}`);
  }
}
if (riskyPresent.length > 0) {
  console.log('- data license cleanup is still required before a competition-final submission');
}

if (process.argv.includes('--strict') && blockers.length > 0) {
  process.exitCode = 1;
}
