import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

import {
  buildWebhookPayload,
  defaultRetryReasonForMode,
  hasLabel,
  isRetryCandidate,
  openFixPrSearchQuery,
  parseRetryDispatchArgs,
  resolveDispatchAction,
  isEpicIssue,
  resolveEpicDispatchAction,
  resolveImplementDispatchGate,
  isEpicCloseCheckCandidate,
  collectReconcileDispatchCandidates,
  selectReconcileDispatchCandidate,
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
    issueLabels: 'agent-ready',
    hasOpenFixPr: false,
  });
  assert.deepEqual(result, { eligible: true, action: 'implement' });
});

test('isRetryCandidate rejects when agent-in-progress is present', () => {
  const result = isRetryCandidate({
    issueLabels: 'agent-ready,agent-in-progress',
    hasOpenFixPr: false,
  });
  assert.deepEqual(result, { eligible: false, reason: 'has agent-in-progress' });
});

test('isRetryCandidate rejects when an open fix PR exists', () => {
  const result = isRetryCandidate({
    issueLabels: 'agent-ready',
    hasOpenFixPr: true,
  });
  assert.deepEqual(result, { eligible: false, reason: 'open fix pr exists' });
});

test('isRetryCandidate rejects when agent-close is present', () => {
  const result = isRetryCandidate({
    issueLabels: 'agent-ready,agent-close',
    hasOpenFixPr: false,
  });
  assert.deepEqual(result, { eligible: false, reason: 'agent-close present' });
});

test('isRetryCandidate ignores legacy stop labels when agent-ready is present', () => {
  assert.deepEqual(
    isRetryCandidate({
      issueLabels: 'agent-ready,agent-skipped',
      hasOpenFixPr: false,
    }),
    { eligible: true, action: 'implement' },
  );
  assert.deepEqual(
    isRetryCandidate({
      issueLabels: 'agent-ready,wontfix',
      hasOpenFixPr: false,
    }),
    { eligible: true, action: 'implement' },
  );
});

test('isRetryCandidate rejects only agent-in-progress among stop labels', () => {
  assert.deepEqual(
    isRetryCandidate({
      issueLabels: 'agent-ready,agent-in-progress',
      hasOpenFixPr: false,
    }),
    { eligible: false, reason: 'has agent-in-progress' },
  );
});

test('isRetryCandidate rejects issues without agent-ready', () => {
  const result = isRetryCandidate({
    issueLabels: 'enhancement',
    hasOpenFixPr: false,
  });
  assert.deepEqual(result, { eligible: false, reason: 'no agent-ready' });
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

test('dispatch lib does not export dependency parsers or gates', async () => {
  const source = await readFile(new URL('./issue-worker-dispatch-lib.mjs', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /export function parseHardDependencyIssueNumbers/);
  assert.doesNotMatch(source, /export function parseDependencyIssueNumbers/);
  assert.doesNotMatch(source, /resolveDependencyGate/);
  assert.doesNotMatch(source, /agent-deps-ready/);
  assert.doesNotMatch(source, /agent-deps-wait-/);
});

test('resolveDispatchAction implements when agent-ready is present', () => {
  const result = resolveDispatchAction({
    eventAction: 'labeled',
    labelName: 'agent-ready',
    issueAuthor: 'rick-chick',
    issueLabels: 'agent-ready,agent-skipped',
  });
  assert.deepEqual(result, { skip: false, action: 'implement' });
});

test('isEpicIssue detects epic title and label', () => {
  assert.equal(isEpicIssue('[epic] Parent issue', ''), true);
  assert.equal(isEpicIssue('Parent issue', 'epic,agent-ready'), true);
  assert.equal(isEpicIssue('Child issue', 'agent-ready'), false);
});

test('resolveEpicDispatchAction remaps implement to epic_close_check for epic title', () => {
  assert.deepEqual(
    resolveEpicDispatchAction({
      action: 'implement',
      issueTitle: '[epic] Parent issue',
      issueLabels: '',
    }),
    { action: 'epic_close_check' },
  );
});

test('resolveEpicDispatchAction remaps implement to epic_close_check for epic label', () => {
  assert.deepEqual(
    resolveEpicDispatchAction({
      action: 'implement',
      issueTitle: 'Parent issue',
      issueLabels: 'epic,agent-ready',
    }),
    { action: 'epic_close_check' },
  );
});

test('resolveEpicDispatchAction leaves non-epic implement unchanged', () => {
  assert.deepEqual(
    resolveEpicDispatchAction({
      action: 'implement',
      issueTitle: 'Child issue',
      issueLabels: 'agent-ready',
    }),
    { action: 'implement' },
  );
});

test('resolveEpicDispatchAction leaves triage unchanged for epic title', () => {
  assert.deepEqual(
    resolveEpicDispatchAction({
      action: 'triage',
      issueTitle: '[epic] Parent issue',
      issueLabels: 'epic',
    }),
    { action: 'triage' },
  );
});

test('isRetryCandidate returns epic_close_check for epic issues', () => {
  const result = isRetryCandidate({
    issueLabels: 'agent-ready',
    issueTitle: '[epic] Parent issue',
    hasOpenFixPr: false,
  });
  assert.deepEqual(result, { eligible: true, action: 'epic_close_check' });
});

test('isEpicCloseCheckCandidate does not require agent-ready', () => {
  const result = isEpicCloseCheckCandidate({
    issueTitle: '[epic] Parent',
    issueLabels: 'agent-skipped',
    hasOpenFixPr: false,
  });
  assert.deepEqual(result, { eligible: true, action: 'epic_close_check' });
});

test('collectReconcileDispatchCandidates includes all structurally eligible issues', () => {
  const issues = [
    {
      number: 384,
      title: 'ready',
      labels: ['agent-ready'],
      body: '## 依存\n\n- #362',
    },
    {
      number: 398,
      title: 'ready2',
      labels: ['agent-ready'],
      body: '## 依存\n\n- なし',
    },
  ];
  const candidates = collectReconcileDispatchCandidates([], issues, () => false);
  assert.deepEqual(candidates, [
    { issue: issues[0], action: 'implement' },
    { issue: issues[1], action: 'implement' },
  ]);
});

test('collectReconcileDispatchCandidates skips in-progress issues', () => {
  const issues = [
    { number: 384, title: 'blocked', labels: ['agent-ready', 'agent-in-progress'], body: '' },
    { number: 398, title: 'ready', labels: ['agent-ready'], body: '' },
  ];
  const candidates = collectReconcileDispatchCandidates([], issues, () => false);
  assert.deepEqual(candidates, [{ issue: issues[1], action: 'implement' }]);
});

test('selectReconcileDispatchCandidate prefers implement over epic_close_check', () => {
  const selected = selectReconcileDispatchCandidate([
    {
      issue: { number: 362, title: '[epic] Parent', labels: ['agent-skipped'] },
      action: 'epic_close_check',
    },
    {
      issue: { number: 323, title: 'Child', labels: ['agent-ready'] },
      action: 'implement',
    },
  ]);
  assert.deepEqual(selected, {
    issue: { number: 323, title: 'Child', labels: ['agent-ready'] },
    action: 'implement',
  });
});

test('selectReconcileDispatchCandidate prefers implement over agent-ready epic', () => {
  const selected = selectReconcileDispatchCandidate([
    {
      issue: { number: 316, title: '[epic] Parent', labels: ['agent-ready'] },
      action: 'epic_close_check',
    },
    {
      issue: { number: 323, title: 'Child', labels: ['agent-ready'] },
      action: 'implement',
    },
  ]);
  assert.deepEqual(selected, {
    issue: { number: 323, title: 'Child', labels: ['agent-ready'] },
    action: 'implement',
  });
});

test('selectReconcileDispatchCandidate picks lowest implement number', () => {
  const selected = selectReconcileDispatchCandidate([
    { issue: { number: 355, title: 'c', labels: ['agent-ready'] }, action: 'implement' },
    { issue: { number: 323, title: 'a', labels: ['agent-ready'] }, action: 'implement' },
    { issue: { number: 340, title: 'b', labels: ['agent-ready'] }, action: 'implement' },
  ]);
  assert.equal(selected?.issue.number, 323);
});

test('selectReconcileDispatchCandidate picks lowest epic when no implement', () => {
  const selected = selectReconcileDispatchCandidate([
    { issue: { number: 400, title: '[epic] c', labels: [] }, action: 'epic_close_check' },
    { issue: { number: 316, title: '[epic] a', labels: [] }, action: 'epic_close_check' },
    { issue: { number: 362, title: '[epic] b', labels: [] }, action: 'epic_close_check' },
  ]);
  assert.equal(selected?.issue.number, 316);
});

test('selectReconcileDispatchCandidate deprioritizes last dispatched when alternatives exist', () => {
  const selected = selectReconcileDispatchCandidate(
    [
      { issue: { number: 323, title: 'a', labels: ['agent-ready'] }, action: 'implement' },
      { issue: { number: 340, title: 'b', labels: ['agent-ready'] }, action: 'implement' },
    ],
    { deprioritizeIssueNumber: 323 },
  );
  assert.equal(selected?.issue.number, 340);
});

test('selectReconcileDispatchCandidate keeps sole candidate when deprioritized', () => {
  const selected = selectReconcileDispatchCandidate(
    [{ issue: { number: 362, title: '[epic]', labels: [] }, action: 'epic_close_check' }],
    { deprioritizeIssueNumber: 362 },
  );
  assert.equal(selected?.issue.number, 362);
});

test('selectReconcileDispatchCandidate returns null for empty candidates', () => {
  assert.equal(selectReconcileDispatchCandidate([]), null);
});

test('collectReconcileDispatchCandidates does not duplicate agent-ready epic', () => {
  const epic = {
    number: 316,
    title: '[epic] Parent',
    labels: ['agent-ready'],
    body: '## 子 Issue\n\n- #323',
  };
  const candidates = collectReconcileDispatchCandidates([], [epic], () => false);
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].issue.number, 316);
  assert.equal(candidates[0].action, 'epic_close_check');
});

test('collectReconcileDispatchCandidates includes epic without agent-ready and implement', () => {
  const candidates = collectReconcileDispatchCandidates(
    [
      {
        number: 362,
        title: '[epic] Later',
        labels: ['agent-skipped'],
        body: '',
      },
    ],
    [
      {
        number: 323,
        title: 'Child',
        labels: ['agent-ready'],
        body: '',
      },
    ],
    () => false,
  );
  assert.equal(candidates.length, 2);
  const actions = candidates.map((entry) => `${entry.issue.number}:${entry.action}`);
  assert.deepEqual(actions, ['362:epic_close_check', '323:implement']);
});

test('parseRetryDispatchArgs parses repo and number', () => {
  assert.deepEqual(
    parseRetryDispatchArgs(['node', 'script', 'issue', '--repo', 'o/r', '--number', '42']),
    { mode: 'issue', repo: 'o/r', number: '42' },
  );
});

test('defaultRetryReasonForMode maps reconcile', () => {
  assert.equal(defaultRetryReasonForMode('reconcile'), 'scheduled_reconcile');
});

test('buildWebhookPayload includes issue number', () => {
  const payload = buildWebhookPayload({
    repository: 'rick-chick/agrr',
    issueNumber: 42,
    issueTitle: 'title',
    issueUrl: 'https://github.com/rick-chick/agrr/issues/42',
    labels: 'agent-ready',
    retryReason: 'scheduled_reconcile',
  });
  assert.equal(payload.issue_number, 42);
  assert.equal(payload.retry_reason, 'scheduled_reconcile');
});
