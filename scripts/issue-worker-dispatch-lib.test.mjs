import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  buildWebhookPayload,
  defaultRetryReasonForMode,
  hasLabel,
  isRetryCandidate,
  openFixPrSearchQuery,
  parseDependencyIssueNumbers,
  parseRetryDispatchArgs,
  resolveDependencyGate,
  resolveDispatchAction,
  resolveEpicImplementGate,
  resolveImplementDispatchGate,
  selectOpenIssueByTitle,
  selectRetryCandidate,
  formatDependencyGateComment,
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

test('parseDependencyIssueNumbers extracts issue numbers from ## 依存 section', () => {
  const body = [
    '## 背景',
    '',
    'text',
    '',
    '## 依存',
    '',
    '- #317（基盤）',
    '- #320（後続）',
    '',
    '## 参照',
    '',
    '- #999',
  ].join('\n');
  assert.deepEqual(parseDependencyIssueNumbers(body), [317, 320]);
});

test('parseDependencyIssueNumbers returns empty when section is なし only', () => {
  const body = ['## 依存', '', '- なし', '', '## 参照'].join('\n');
  assert.deepEqual(parseDependencyIssueNumbers(body), []);
});

test('parseDependencyIssueNumbers returns empty when section is missing', () => {
  assert.deepEqual(parseDependencyIssueNumbers('## 背景\n\nno deps'), []);
});

test('resolveDependencyGate passes when all dependencies are closed', async () => {
  const body = ['## 依存', '', '- #317'].join('\n');
  const result = await resolveDependencyGate({
    issueNumber: 318,
    issueBody: body,
    fetchIssueState: async (number) => (number === 317 ? 'CLOSED' : 'OPEN'),
  });
  assert.deepEqual(result, { skip: false });
});

test('resolveDependencyGate blocks when a dependency is open', async () => {
  const body = ['## 依存', '', '- #317'].join('\n');
  const result = await resolveDependencyGate({
    issueNumber: 318,
    issueBody: body,
    fetchIssueState: async (number) => (number === 317 ? 'OPEN' : 'CLOSED'),
  });
  assert.deepEqual(result, {
    skip: true,
    skipReason: 'dependency #317 is open',
    openDependencies: [317],
  });
});

test('resolveDependencyGate detects circular dependency', async () => {
  const body318 = ['## 依存', '', '- #317'].join('\n');
  const body317 = ['## 依存', '', '- #318'].join('\n');
  const bodies = { 317: body317, 318: body318 };
  await assert.rejects(
    () =>
      resolveDependencyGate({
        issueNumber: 318,
        issueBody: body318,
        fetchIssueState: async (number) => 'OPEN',
        fetchIssueBody: async (number) => bodies[number] ?? '',
      }),
    /circular dependency/i,
  );
});

test('resolveDispatchAction skips agent-ready when agent-skipped is present', () => {
  const result = resolveDispatchAction({
    eventAction: 'labeled',
    labelName: 'agent-ready',
    issueAuthor: 'rick-chick',
    issueLabels: 'agent-ready,agent-skipped',
  });
  assert.deepEqual(result, {
    skip: true,
    skipReason: 'agent-ready with agent-skipped requires removing agent-skipped first',
  });
});

test('resolveEpicImplementGate skips implement for epic title', () => {
  assert.deepEqual(
    resolveEpicImplementGate({
      action: 'implement',
      issueTitle: '[epic] Parent issue',
      issueLabels: '',
    }),
    {
      skip: true,
      skipReason: 'epic issues cannot be dispatched for implement',
    },
  );
});

test('resolveEpicImplementGate skips implement for epic label', () => {
  assert.deepEqual(
    resolveEpicImplementGate({
      action: 'implement',
      issueTitle: 'Parent issue',
      issueLabels: 'epic,agent-ready',
    }),
    {
      skip: true,
      skipReason: 'epic issues cannot be dispatched for implement',
    },
  );
});

test('resolveEpicImplementGate allows triage for epic title', () => {
  assert.deepEqual(
    resolveEpicImplementGate({
      action: 'triage',
      issueTitle: '[epic] Parent issue',
      issueLabels: 'epic',
    }),
    { skip: false },
  );
});

test('formatDependencyGateComment includes open dependency numbers', () => {
  const comment = formatDependencyGateComment([317, 320]);
  assert.match(comment, /#317/);
  assert.match(comment, /#320/);
  assert.match(comment, /dispatch 保留/);
});
