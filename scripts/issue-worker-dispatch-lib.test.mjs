import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildWebhookPayload,
  hasLabel,
  isRetryCandidate,
  resolveDispatchAction,
  selectRetryCandidate,
} from './issue-worker-dispatch-lib.mjs';

test('hasLabel matches comma-separated labels', () => {
  assert.equal(hasLabel('enhancement,agent-ready', 'agent-ready'), true);
  assert.equal(hasLabel('agent-ready', 'agent-ready'), true);
  assert.equal(hasLabel('enhancement', 'agent-ready'), false);
});

test('resolveDispatchAction dispatches implement on opened with agent-ready', () => {
  const result = resolveDispatchAction({
    eventAction: 'opened',
    labelName: '',
    issueAuthor: 'rick-chick',
    issueLabels: 'enhancement,agent-ready',
  });
  assert.deepEqual(result, { skip: false, action: 'implement' });
});

test('resolveDispatchAction dispatches close_with_reason on opened with agent-close', () => {
  const result = resolveDispatchAction({
    eventAction: 'opened',
    labelName: '',
    issueAuthor: 'rick-chick',
    issueLabels: 'agent-close',
  });
  assert.deepEqual(result, { skip: false, action: 'close_with_reason' });
});

test('resolveDispatchAction triages plain opened issues', () => {
  const result = resolveDispatchAction({
    eventAction: 'opened',
    labelName: '',
    issueAuthor: 'rick-chick',
    issueLabels: 'enhancement',
  });
  assert.deepEqual(result, { skip: false, action: 'triage' });
});

test('resolveDispatchAction skips bot-authored opened issues', () => {
  const result = resolveDispatchAction({
    eventAction: 'opened',
    labelName: '',
    issueAuthor: 'dependabot[bot]',
    issueLabels: 'enhancement',
  });
  assert.deepEqual(result, {
    skip: true,
    skipReason: 'bot-authored issue',
  });
});

test('resolveDispatchAction implements on agent-ready labeled event', () => {
  const result = resolveDispatchAction({
    eventAction: 'labeled',
    labelName: 'agent-ready',
    issueAuthor: 'rick-chick',
    issueLabels: 'enhancement,agent-ready',
  });
  assert.deepEqual(result, { skip: false, action: 'implement' });
});

test('resolveDispatchAction skips unrelated labeled events', () => {
  const result = resolveDispatchAction({
    eventAction: 'labeled',
    labelName: 'enhancement',
    issueAuthor: 'rick-chick',
    issueLabels: 'enhancement,agent-ready',
  });
  assert.deepEqual(result, {
    skip: true,
    skipReason: 'labeled event is not agent-ready or agent-close',
  });
});

test('isRetryCandidate accepts agent-ready without blockers', () => {
  const result = isRetryCandidate({
    issueLabels: 'enhancement,agent-ready',
    hasOpenFixPr: false,
  });
  assert.deepEqual(result, { eligible: true, action: 'implement' });
});

test('isRetryCandidate rejects when agent-in-progress is present', () => {
  const result = isRetryCandidate({
    issueLabels: 'agent-ready,agent-in-progress',
    hasOpenFixPr: false,
  });
  assert.equal(result.eligible, false);
  assert.match(result.reason, /agent-in-progress/);
});

test('isRetryCandidate rejects when an open fix PR exists', () => {
  const result = isRetryCandidate({
    issueLabels: 'agent-ready',
    hasOpenFixPr: true,
  });
  assert.deepEqual(result, {
    eligible: false,
    reason: 'open fix pr exists',
  });
});

test('selectRetryCandidate picks the lowest eligible issue number', () => {
  const selected = selectRetryCandidate(
    [
      { number: 207, labels: ['agent-ready'] },
      { number: 206, labels: ['agent-ready', 'agent-in-progress'] },
      { number: 208, labels: ['agent-ready'] },
    ],
    (issueNumber) => issueNumber === 208,
  );
  assert.deepEqual(selected, {
    issue: { number: 207, labels: ['agent-ready'] },
    action: 'implement',
  });
});

test('buildWebhookPayload includes retry metadata when provided', () => {
  const payload = buildWebhookPayload({
    repository: 'rick-chick/agrr',
    issueNumber: 207,
    issueTitle: 'Example',
    issueUrl: 'https://github.com/rick-chick/agrr/issues/207',
    action: 'implement',
    labels: 'agent-ready',
    issueBody: 'body',
    retryReason: 'dispatch_run_cancelled',
  });
  assert.equal(payload.retry_reason, 'dispatch_run_cancelled');
  assert.equal(payload.issue_number, 207);
});
