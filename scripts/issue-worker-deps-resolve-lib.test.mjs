import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildDepsResolveWebhookPayload,
  parseDepsResolveArgs,
  resolveDepsAgentWebhookEnv,
} from './issue-worker-deps-resolve-lib.mjs';

test('parseDepsResolveArgs reads --repo and --number', () => {
  assert.deepEqual(
    parseDepsResolveArgs(['node', 'script', '--repo', 'owner/repo', '--number', '318']),
    { repo: 'owner/repo', number: 318 },
  );
});

test('parseDepsResolveArgs defaults repo when omitted', () => {
  assert.deepEqual(parseDepsResolveArgs(['node', 'script', '--number', '42']), {
    repo: 'rick-chick/agrr',
    number: 42,
  });
});

test('parseDepsResolveArgs rejects missing or invalid --number', () => {
  assert.throws(
    () => parseDepsResolveArgs(['node', 'script']),
    /--number must be a positive integer/,
  );
  assert.throws(
    () => parseDepsResolveArgs(['node', 'script', '--number', '0']),
    /--number must be a positive integer/,
  );
  assert.throws(
    () => parseDepsResolveArgs(['node', 'script', '--number', 'abc']),
    /--number must be a positive integer/,
  );
});

test('buildDepsResolveWebhookPayload includes body_hash and omits action', () => {
  const payload = buildDepsResolveWebhookPayload({
    repo: 'rick-chick/agrr',
    issueNumber: 318,
    issueTitle: 'Child issue',
    issueUrl: 'https://github.com/rick-chick/agrr/issues/318',
    issueBody: '## 依存\n\n- #317',
    bodyHash: 'abc123deadbeef',
  });
  assert.equal(payload.repository, 'rick-chick/agrr');
  assert.equal(payload.issue_number, 318);
  assert.equal(payload.issue_title, 'Child issue');
  assert.equal(payload.issue_url, 'https://github.com/rick-chick/agrr/issues/318');
  assert.equal(payload.issue_body, '## 依存\n\n- #317');
  assert.equal(payload.body_hash, 'abc123deadbeef');
  assert.equal('action' in payload, false);
});

test('resolveDepsAgentWebhookEnv reports configured only when url and key are set', () => {
  assert.deepEqual(
    resolveDepsAgentWebhookEnv({
      CURSOR_DELIVERY_WEBHOOK_URL: 'https://example.test/hook',
      CURSOR_DELIVERY_WEBHOOK_KEY: 'secret',
    }),
    {
      configured: true,
      url: 'https://example.test/hook',
      key: 'secret',
    },
  );
  assert.equal(
    resolveDepsAgentWebhookEnv({
      CURSOR_DELIVERY_WEBHOOK_URL: 'https://example.test/hook',
    }).configured,
    false,
  );
  assert.equal(resolveDepsAgentWebhookEnv({}).configured, false);
});
