import { buildDeliveryPrPayload } from './delivery-dispatch-lib.mjs';
import { postWebhookJson, WebhookPostError } from './webhook-post-lib.mjs';

/** @typedef {{ name: string; payload: Record<string, unknown> }} WebhookSmokeCase */

/** @type {WebhookSmokeCase[]} */
export const DELIVERY_WEBHOOK_SMOKE_CASES = [
  {
    name: 'pr_unlinked',
    payload: buildDeliveryPrPayload({
      repository: 'rick-chick/agrr',
      prNumber: 431,
      issueNumber: null,
    }),
  },
];

/**
 * @param {{
 *   url: string;
 *   bearerToken: string;
 *   cases?: WebhookSmokeCase[];
 *   execFileSync: typeof import('node:child_process').execFileSync;
 *   log?: (message: string) => void;
 * }} input
 * @returns {{ ok: true; results: Array<{ name: string; statusCode: number }> }}
 */
export function runDeliveryWebhookSmoke({
  url,
  bearerToken,
  cases = DELIVERY_WEBHOOK_SMOKE_CASES,
  execFileSync,
  log = console.log,
}) {
  if (!url || !bearerToken) {
    throw new Error('WEBHOOK_URL and WEBHOOK_KEY are required for delivery webhook smoke');
  }

  /** @type {Array<{ name: string; statusCode: number }>} */
  const results = [];

  for (const testCase of cases) {
    log(`Smoke case: ${testCase.name}`);
    log(`Payload: ${JSON.stringify(testCase.payload)}`);
    const result = postWebhookJson({
      url,
      bearerToken,
      body: testCase.payload,
      execFileSync,
      maxAttempts: 1,
      log,
    });
    results.push({ name: testCase.name, statusCode: result.statusCode });
    log(`Smoke case ${testCase.name}: HTTP ${result.statusCode}`);
  }

  return { ok: true, results };
}

/**
 * @param {unknown} error
 * @returns {string}
 */
export function formatWebhookSmokeFailure(error) {
  if (error instanceof WebhookPostError) {
    const parts = [
      error.message,
      error.responseBody ? `response: ${error.responseBody}` : null,
    ].filter(Boolean);
    return parts.join(' — ');
  }
  return error instanceof Error ? error.message : String(error);
}
