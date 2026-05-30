#!/usr/bin/env node
/**
 * route-manifest の全 pattern × CAPTURE_LOCALES に対応する PNG が e2e/agent-review/out にあることを検証する。
 * `npm run e2e:capture-for-agent` の末尾で実行する。
 */
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { CAPTURE_LOCALES, agentPngFilename } from '../capture-locales.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND = join(__dirname, '..', '..');
const manifestPath = join(FRONTEND, 'e2e', 'route-manifest.json');
const outDir = join(__dirname, 'out');

const manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
const routes = manifest.routes;
if (!Array.isArray(routes) || routes.length === 0) {
  console.error('verify-capture-complete: route-manifest.json に routes がありません');
  process.exit(1);
}

/** dev-session キャプチャでは auth 系は別 spec（login-capture-for-agent.spec.ts）で未ログイン撮影 */
const SKIP_PATTERNS = new Set();

const routesToVerify = routes.filter((r) => !SKIP_PATTERNS.has(r.pattern));

const missing = [];
for (const r of routesToVerify) {
  for (const locale of CAPTURE_LOCALES) {
    const name = agentPngFilename(r.pattern, locale);
    const f = join(outDir, name);
    if (!existsSync(f)) {
      missing.push({ pattern: r.pattern, locale, expected: f });
    }
  }
}

const expectedCount = routesToVerify.length * CAPTURE_LOCALES.length;
if (missing.length > 0) {
  console.error(
    `verify-capture-complete: 不足 ${missing.length} / ${expectedCount} 件（route × locale）`,
  );
  for (const m of missing) {
    console.error(
      `  - pattern=${JSON.stringify(m.pattern)} locale=${m.locale} → ${m.expected}`,
    );
  }
  process.exit(1);
}

console.log(
  `verify-capture-complete: OK ${expectedCount} PNGs (${routesToVerify.length} routes × ${CAPTURE_LOCALES.join(', ')}; skip ${[...SKIP_PATTERNS].join(', ')}) under ${outDir}`,
);
