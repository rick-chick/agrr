#!/usr/bin/env node
/**
 * Post Issue Worker Delivery Agent webhook (no issue_body in payload).
 *
 * Env: WEBHOOK_URL, WEBHOOK_KEY, REPOSITORY, ISSUE_NUMBER,
 *      ISSUE_TITLE, ISSUE_URL, LABELS
 */
import { execFileSync } from 'node:child_process';

import { buildDeliveryIssuePayload } from './delivery-dispatch-lib.mjs';
import { postWebhookJson } from './webhook-post-lib.mjs';

const webhookUrl = process.env.WEBHOOK_URL ?? '';
const webhookKey = process.env.WEBHOOK_KEY ?? '';

if (!webhookUrl || !webhookKey) {
  console.log('WEBHOOK_URL or WEBHOOK_KEY is not set; skipping dispatch.');
  process.exit(0);
}

const issueNumber = Number(process.env.ISSUE_NUMBER);
if (!Number.isInteger(issueNumber) || issueNumber <= 0) {
  console.error('ISSUE_NUMBER must be a positive integer');
  process.exit(1);
}

const payload = buildDeliveryIssuePayload({
  repository: process.env.REPOSITORY ?? process.env.GITHUB_REPOSITORY ?? '',
  issueNumber,
  issueTitle: process.env.ISSUE_TITLE,
  issueUrl: process.env.ISSUE_URL,
  labels: process.env.LABELS,
});

postWebhookJson({
  url: webhookUrl,
  bearerToken: webhookKey,
  body: payload,
  execFileSync,
});
