import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  DELIVERY_WEBHOOK_SMOKE_CASES,
  formatWebhookSmokeFailure,
  runDeliveryWebhookSmoke,
} from './verify-delivery-webhook-smoke-lib.mjs';
import { WebhookPostError } from './webhook-post-lib.mjs';

test('DELIVERY_WEBHOOK_SMOKE_CASES includes pr_unlinked contract payload', () => {
  const prUnlinked = DELIVERY_WEBHOOK_SMOKE_CASES.find((item) => item.name === 'pr_unlinked');
  assert.ok(prUnlinked);
  assert.equal(prUnlinked.payload.repository, 'rick-chick/agrr');
  assert.equal(prUnlinked.payload.pr_number, 431);
  assert.equal(prUnlinked.payload.pr_unlinked, true);
  assert.equal('issue_number' in prUnlinked.payload, false);
});

test('runDeliveryWebhookSmoke posts each case once', () => {
  const calls = [];
  const result = runDeliveryWebhookSmoke({
    url: 'https://example.com/webhook',
    bearerToken: 'secret',
    cases: DELIVERY_WEBHOOK_SMOKE_CASES,
    execFileSync: (_cmd, argv) => {
      calls.push(argv);
      return '\n200';
    },
    log: () => {},
  });
  assert.equal(result.ok, true);
  assert.equal(result.results.length, DELIVERY_WEBHOOK_SMOKE_CASES.length);
  assert.equal(calls.length, DELIVERY_WEBHOOK_SMOKE_CASES.length);
});

test('formatWebhookSmokeFailure includes response body when present', () => {
  const message = formatWebhookSmokeFailure(
    new WebhookPostError('Webhook POST failed: HTTP 400', {
      statusCode: 400,
      responseBody: '{"code":"invalid"}',
    }),
  );
  assert.match(message, /HTTP 400/);
  assert.match(message, /invalid/);
});
