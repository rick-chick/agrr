#!/usr/bin/env node
/**
 * Smoke-test Delivery Agent webhook payloads (requires live secrets).
 *
 * Usage:
 *   WEBHOOK_URL=... WEBHOOK_KEY=... node scripts/verify-delivery-webhook-smoke.mjs
 */
import { execFileSync } from 'node:child_process';

import {
  formatWebhookSmokeFailure,
  runDeliveryWebhookSmoke,
} from './verify-delivery-webhook-smoke-lib.mjs';

const webhookUrl = process.env.WEBHOOK_URL ?? '';
const webhookKey = process.env.WEBHOOK_KEY ?? '';

if (!webhookUrl || !webhookKey) {
  console.error('verify-delivery-webhook-smoke: set WEBHOOK_URL and WEBHOOK_KEY');
  process.exit(1);
}

try {
  const result = runDeliveryWebhookSmoke({
    url: webhookUrl,
    bearerToken: webhookKey,
    execFileSync,
    log: console.log,
  });
  console.log(JSON.stringify(result, null, 2));
} catch (error) {
  console.error(formatWebhookSmokeFailure(error));
  process.exit(1);
}
