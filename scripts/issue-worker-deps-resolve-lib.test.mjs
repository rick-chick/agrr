import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildDepsResolveWebhookPayload,
  parseDepsResolveArgs,
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
    /positive integer/,
  );
  assert.throws(
    () => parseDepsResolveArgs(['node', 'script', '--number', '0']),
    /positive integer/,
  );
  assert.throws(
    () => parseDepsResolveArgs(['node', 'script', '--number', 'abc']),
    /positive integer/,
  );
});

test('buildDepsResolveWebhookPayload omits body_hash and action', () => {
  const payload = buildDepsResolveWebhookPayload({
    repo: 'rick-chick/agrr',
    issueNumber: 318,
    issueTitle: 'Child',
    issueUrl: 'https://github.com/rick-chick/agrr/issues/318',
  });
  assert.deepEqual(payload, {
    repository: 'rick-chick/agrr',
    issue_number: 318,
    issue_title: 'Child',
    issue_url: 'https://github.com/rick-chick/agrr/issues/318',
  });
  assert.equal('body_hash' in payload, false);
  assert.equal('issue_body' in payload, false);
  assert.equal('action' in payload, false);
});
