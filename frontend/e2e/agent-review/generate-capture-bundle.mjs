#!/usr/bin/env node
/**
 * キャプチャ完了後に agent-review-bundle.json を生成する。
 *
 * 使い方:
 *   node e2e/agent-review/generate-capture-bundle.mjs
 *   node e2e/agent-review/generate-capture-bundle.mjs --merge   # 差分キャプチャ後に既存 bundle をマージ
 */
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { generateCaptureBundle } from './agent-review-bundle-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND = join(__dirname, '..', '..');
const REPO_ROOT = join(FRONTEND, '..');
const merge = process.argv.includes('--merge');

const bundle = await generateCaptureBundle({
  frontendRoot: FRONTEND,
  repoRoot: REPO_ROOT,
  mergeExisting: merge,
});

console.log(
  `generate-capture-bundle: OK runId=${bundle.runId} artifacts=${bundle.artifacts.length}`,
);
