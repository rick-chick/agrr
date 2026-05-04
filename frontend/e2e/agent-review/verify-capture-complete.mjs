#!/usr/bin/env node
/**
 * route-manifest の全 pattern に対応する PNG が e2e/agent-review/out にあることを検証する。
 * `npm run e2e:capture-for-agent` の末尾で実行する。
 */
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND = join(__dirname, '..', '..');
const manifestPath = join(FRONTEND, 'e2e', 'route-manifest.json');
const outDir = join(__dirname, 'out');

function pngBasename(pattern) {
  if (pattern === '') return 'home';
  if (pattern === '**') return 'not-found';
  return pattern.replace(/[^\w.-]+/g, '_');
}

const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
const routes = manifest.routes;
if (!Array.isArray(routes) || routes.length === 0) {
  console.error('verify-capture-complete: route-manifest.json に routes がありません');
  process.exit(1);
}

const missing = [];
for (const r of routes) {
  const f = join(outDir, `${pngBasename(r.pattern)}.png`);
  if (!existsSync(f)) {
    missing.push({ pattern: r.pattern, expected: f });
  }
}

if (missing.length > 0) {
  console.error(
    `verify-capture-complete: 不足 ${missing.length} / ${routes.length} 件（route-manifest 対 PNG）`,
  );
  for (const m of missing) {
    console.error(`  - pattern=${JSON.stringify(m.pattern)} → ${m.expected}`);
  }
  process.exit(1);
}

console.log(`verify-capture-complete: OK ${routes.length} PNGs under ${outDir}`);
