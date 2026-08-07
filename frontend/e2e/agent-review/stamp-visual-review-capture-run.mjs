#!/usr/bin/env node
/**
 * visual-review-results.md のメタに bundle.runId を刻む。
 */
import { readFile, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  bundlePath,
  stampVisualReviewCaptureRunId,
} from './agent-review-bundle-lib.mjs';

const __dirname = fileURLToPath(new URL('.', import.meta.url));
const FRONTEND = join(__dirname, '..', '..');
const reviewPath = join(FRONTEND, 'e2e/agent-review/visual-review-results.md');

const bundle = JSON.parse(await readFile(bundlePath(FRONTEND), 'utf8'));
const markdown = await readFile(reviewPath, 'utf8');
const updated = stampVisualReviewCaptureRunId(markdown, bundle.runId);
await writeFile(reviewPath, updated);
console.log(`stamp-visual-review-capture-run: OK captureRunId=${bundle.runId}`);
