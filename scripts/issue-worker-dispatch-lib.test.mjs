import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildWebhookPayload,
  defaultRetryReasonForMode,
  hasLabel,
  isRetryCandidate,
  openFixPrSearchQuery,
  parseRetryDispatchArgs,
  resolveDispatchAction,
  resolveImplementDispatchGate,
  selectOpenIssueByTitle,
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

test('parseRetryDispatchArgs parses reconcile mode with defaults', () => {
  const args = parseRetryDispatchArgs(['node', 'script', 'reconcile']);
  assert.deepEqual(args, {
    mode: 'reconcile',
    repo: 'rick-chick/agrr',
  });
});

test('parseRetryDispatchArgs parses from-title flags', () => {
  const args = parseRetryDispatchArgs([
    'node',
    'script',
    'from-title',
    '--title',
    'Fix task schedule',
    '--repo',
    'owner/repo',
    '--retry-reason',
    'dispatch_run_cancelled',
  ]);
  assert.equal(args.mode, 'from-title');
  assert.equal(args.title, 'Fix task schedule');
  assert.equal(args.repo, 'owner/repo');
  assert.equal(args.retryReason, 'dispatch_run_cancelled');
});

test('parseRetryDispatchArgs parses issue number mode', () => {
  const args = parseRetryDispatchArgs(['node', 'script', 'issue', '--number', '42']);
  assert.equal(args.mode, 'issue');
  assert.equal(args.number, '42');
  assert.equal(args.repo, 'rick-chick/agrr');
});

test('selectOpenIssueByTitle picks the lowest matching issue number', () => {
  const selected = selectOpenIssueByTitle(
    [
      { number: 210, title: 'Same title' },
      { number: 207, title: 'Same title' },
      { number: 208, title: 'Other title' },
    ],
    'Same title',
  );
  assert.deepEqual(selected, { number: 207, title: 'Same title' });
});

test('selectOpenIssueByTitle returns null when no title matches', () => {
  assert.equal(
    selectOpenIssueByTitle([{ number: 207, title: 'A' }], 'Missing'),
    null,
  );
});

test('defaultRetryReasonForMode maps automation entry points', () => {
  assert.equal(defaultRetryReasonForMode('reconcile'), 'scheduled_reconcile');
  assert.equal(defaultRetryReasonForMode('from-title'), 'dispatch_run_cancelled');
  assert.equal(defaultRetryReasonForMode('issue'), 'manual_retry');
});

test('isRetryCandidate rejects when agent-close is present', () => {
  const result = isRetryCandidate({
    issueLabels: 'agent-ready,agent-close',
    hasOpenFixPr: false,
  });
  assert.deepEqual(result, {
    eligible: false,
    reason: 'agent-close present',
  });
});

test('isRetryCandidate rejects blocked automation labels', () => {
  assert.equal(
    isRetryCandidate({
      issueLabels: 'agent-ready,agent-skipped',
      hasOpenFixPr: false,
    }).reason,
    'has agent-skipped',
  );
  assert.equal(
    isRetryCandidate({
      issueLabels: 'agent-ready,agent-blocked',
      hasOpenFixPr: false,
    }).reason,
    'has agent-blocked',
  );
});

test('isRetryCandidate rejects issues without agent-ready', () => {
  const result = isRetryCandidate({
    issueLabels: 'enhancement',
    hasOpenFixPr: false,
  });
  assert.deepEqual(result, {
    eligible: false,
    reason: 'no agent-ready',
  });
});

test('resolveDispatchAction closes on agent-close labeled event', () => {
  const result = resolveDispatchAction({
    eventAction: 'labeled',
    labelName: 'agent-close',
    issueAuthor: 'rick-chick',
    issueLabels: 'agent-close',
  });
  assert.deepEqual(result, { skip: false, action: 'close_with_reason' });
});

test('resolveDispatchAction skips opened issues with terminal labels', () => {
  const result = resolveDispatchAction({
    eventAction: 'opened',
    labelName: '',
    issueAuthor: 'rick-chick',
    issueLabels: 'agent-in-progress',
  });
  assert.deepEqual(result, {
    skip: true,
    skipReason: 'issue already has a terminal or in-progress label',
  });
});

test('resolveDispatchAction skips unsupported webhook actions', () => {
  const result = resolveDispatchAction({
    eventAction: 'closed',
    labelName: '',
    issueAuthor: 'rick-chick',
    issueLabels: 'agent-ready',
  });
  assert.deepEqual(result, {
    skip: true,
    skipReason: 'unsupported issue event action: closed',
  });
});

test('openFixPrSearchQuery matches fixes and closes wording', () => {
  assert.equal(
    openFixPrSearchQuery(276),
    'is:pr is:open (fixes #276 OR closes #276)',
  );
});

test('resolveImplementDispatchGate skips implement when open fix pr exists', () => {
  assert.deepEqual(
    resolveImplementDispatchGate({ action: 'implement', hasOpenFixPr: true }),
    {
      skip: true,
      skipReason: 'open fix/closes pr already exists for this issue',
    },
  );
  assert.deepEqual(
    resolveImplementDispatchGate({ action: 'implement', hasOpenFixPr: false }),
    { skip: false },
  );
  assert.deepEqual(
    resolveImplementDispatchGate({ action: 'triage', hasOpenFixPr: true }),
    { skip: false },
  );
});
