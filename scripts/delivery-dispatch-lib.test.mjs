import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildDeliveryIssuePayload,
  buildDeliveryPrPayload,
  buildDeliveryPrPayloadFromPr,
  parseDispatchedIssueNumberFromLog,
  resolveIssueNumberFromPrBody,
} from './delivery-dispatch-lib.mjs';

test('buildDeliveryIssuePayload omits action field', () => {
  const payload = buildDeliveryIssuePayload({
    repository: 'rick-chick/agrr',
    issueNumber: 323,
    issueTitle: 'Example',
    issueUrl: 'https://github.com/rick-chick/agrr/issues/323',
    labels: 'agent-ready',
    issueBody: 'body',
    retryReason: 'scheduled_reconcile',
  });
  assert.deepEqual(payload, {
    repository: 'rick-chick/agrr',
    issue_number: 323,
    issue_title: 'Example',
    issue_url: 'https://github.com/rick-chick/agrr/issues/323',
    labels: 'agent-ready',
    issue_body: 'body',
    retry_reason: 'scheduled_reconcile',
  });
  assert.equal('action' in payload, false);
});

test('buildDeliveryPrPayload omits undocumented Delivery Agent webhook fields', () => {
  const payload = buildDeliveryPrPayload({
    repository: 'rick-chick/agrr',
    prNumber: 430,
    issueNumber: null,
    prTitle: 'fix(frontend): crop list card overflow menu',
    prUrl: 'https://github.com/rick-chick/agrr/pull/430',
    headRef: 'fix/crop-list-overflow-menu',
    headSha: '891f6e3d0baef1a1c1c3fad8f81a92b32e45a563',
    author: 'rick-chick',
    mergeableState: 'MERGEABLE',
    mergeStateStatus: 'CLEAN',
  });
  assert.deepEqual(payload, {
    repository: 'rick-chick/agrr',
    pr_number: 430,
    pr_title: 'fix(frontend): crop list card overflow menu',
    pr_url: 'https://github.com/rick-chick/agrr/pull/430',
  });
  assert.equal('head_ref' in payload, false);
  assert.equal('head_sha' in payload, false);
  assert.equal('author' in payload, false);
  assert.equal('mergeable_state' in payload, false);
  assert.equal('merge_state_status' in payload, false);
});

test('buildDeliveryPrPayload includes issue_number from Closes when provided', () => {
  const payload = buildDeliveryPrPayload({
    repository: 'rick-chick/agrr',
    prNumber: 427,
    issueNumber: 323,
    prTitle: 'fix',
    prUrl: 'https://github.com/rick-chick/agrr/pull/427',
  });
  assert.equal(payload.pr_number, 427);
  assert.equal(payload.issue_number, 323);
  assert.equal('action' in payload, false);
});

test('resolveIssueNumberFromPrBody parses closes and fixes', () => {
  assert.equal(resolveIssueNumberFromPrBody('Closes #323'), 323);
  assert.equal(resolveIssueNumberFromPrBody('fixes #42'), 42);
  assert.equal(resolveIssueNumberFromPrBody('no ref'), null);
});

test('buildDeliveryPrPayloadFromPr maps PR fields', () => {
  const payload = buildDeliveryPrPayloadFromPr(
    {
      number: 277,
      title: 'fix: crop',
      url: 'https://github.com/rick-chick/agrr/pull/277',
      headRefName: 'cursor/foo',
      headRefOid: 'abc',
      author: { login: 'cursor[bot]' },
      body: 'Closes #276',
      mergeable: 'MERGEABLE',
      mergeStateStatus: 'CLEAN',
    },
    'rick-chick/agrr',
    'scheduled_reconcile',
  );
  assert.equal(payload.issue_number, 276);
  assert.equal(payload.pr_number, 277);
  assert.equal(payload.retry_reason, 'scheduled_reconcile');
  assert.equal('action' in payload, false);
});

test('buildDeliveryIssuePayload supports body_hash for deps judgment runs', () => {
  const payload = {
    ...buildDeliveryIssuePayload({
      repository: 'rick-chick/agrr',
      issueNumber: 318,
      issueTitle: 'Child',
      issueUrl: 'https://github.com/rick-chick/agrr/issues/318',
      issueBody: '## 依存\n\n- #317',
    }),
    body_hash: 'abc123deadbeef',
  };
  assert.equal(payload.issue_number, 318);
  assert.equal(payload.body_hash, 'abc123deadbeef');
  assert.equal('action' in payload, false);
});

test('parseDispatchedIssueNumberFromLog reads Delivery Agent and legacy logs', () => {
  assert.equal(
    parseDispatchedIssueNumberFromLog('Dispatched Delivery Agent for #316 (scheduled_reconcile)'),
    316,
  );
  assert.equal(
    parseDispatchedIssueNumberFromLog('Dispatched Issue Worker retry for #323 (implement)'),
    323,
  );
  assert.equal(parseDispatchedIssueNumberFromLog('no dispatch'), null);
});
