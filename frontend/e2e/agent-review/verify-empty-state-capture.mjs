#!/usr/bin/env node
/**
 * 空状態キャプチャ PNG（4 シナリオ × ja）の存在を検証する。
 * `npm run e2e:capture-for-agent` の末尾で実行する。
 */
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { EMPTY_STATE_SCENARIOS, emptyStatePngFilename } from '../fixtures/empty-state-png-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const outDir = join(__dirname, 'out');

const missing = [];
for (const scenario of EMPTY_STATE_SCENARIOS) {
  const name = emptyStatePngFilename(scenario, 'ja');
  const file = join(outDir, name);
  if (!existsSync(file)) {
    missing.push({ scenario, expected: file });
  }
}

if (missing.length > 0) {
  console.error(`verify-empty-state-capture: 不足 ${missing.length} / ${EMPTY_STATE_SCENARIOS.length} 件`);
  for (const m of missing) {
    console.error(`  - scenario=${m.scenario} → ${m.expected}`);
  }
  process.exit(1);
}

console.log(
  `verify-empty-state-capture: OK ${EMPTY_STATE_SCENARIOS.length} PNGs (ja) under ${outDir}`,
);
