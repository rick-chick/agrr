#!/usr/bin/env node
/**
 * POST JSON payload to Cursor webhook with transient HTTP retries.
 *
 * Reads payload from stdin, or PAYLOAD env when stdin is empty.
 * Env: WEBHOOK_URL, WEBHOOK_KEY
 */
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';

import { postWebhookJson } from './webhook-post-lib.mjs';

function sleepSync(ms) {
  execFileSync('sleep', [String(Math.max(1, Math.ceil(ms / 1000)))]);
}

const webhookUrl = process.env.WEBHOOK_URL ?? '';
const webhookKey = process.env.WEBHOOK_KEY ?? '';

if (!webhookUrl || !webhookKey) {
  console.log('WEBHOOK_URL or WEBHOOK_KEY is not set.');
  process.exit(0);
}

let payload = process.env.PAYLOAD ?? '';
if (!payload) {
  try {
    payload = readFileSync(0, 'utf8');
  } catch {
    payload = '';
  }
}

payload = payload.trim();
if (!payload) {
  console.error('post-cursor-webhook: empty payload (stdin or PAYLOAD env required)');
  process.exit(1);
}

postWebhookJson({
  url: webhookUrl,
  bearerToken: webhookKey,
  body: payload,
  execFileSync,
  sleepSync,
  log: console.log,
});

console.log('Webhook POST succeeded');
