import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';

import { hashDependencySection } from './issue-worker-deps-agent-lib.mjs';
import {
  buildWebhookPayload,
  defaultRetryReasonForMode,
  hasLabel,
  isRetryCandidate,
  openFixPrSearchQuery,
  parseRetryDispatchArgs,
  resolveDependencyGate,
  resolveDependencyGateFromAgentCache,
  resolveDispatchAction,
  isEpicIssue,
  resolveEpicDispatchAction,
  resolveEpicImplementGate,
  resolveImplementDispatchGate,
  resolveImplementPreDispatchGates,
  resolvePreDispatchGates,
  selectDispatchableOnDependencyClosed,
  isEpicCloseCheckCandidate,
  resolveHardDependencies,
  formatDependencyGateComment,
  collectReconcileDispatchCandidates,
  selectReconcileDispatchCandidate,
  parseDispatchedIssueNumberFromLog,
  resolveOnClosedDispatch,
} from './issue-worker-dispatch-lib.mjs';

/**
 * @param {number[]} hardDependencies
 * @param {string} issueBody
 * @returns {{
 *   hard_dependencies: number[];
 *   soft_notes: string[];
 *   rationale: string;
 *   body_hash: string;
 * }}
 */
function agentContract(hardDependencies, issueBody) {
  return {
    hard_dependencies: hardDependencies,
    soft_notes: [],
    rationale: 'fixture',
    body_hash: hashDependencySection(issueBody),
  };
}

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

test('buildWebhookPayload includes retry metadata when provided', () => {
  const payload = buildWebhookPayload({
    repository: 'rick-chick/agrr',
    issueNumber: 207,
    issueTitle: 'Example',
    issueUrl: 'https://github.com/rick-chick/agrr/issues/207',
    labels: 'agent-ready',
    issueBody: 'body',
    retryReason: 'dispatch_run_cancelled',
  });
  assert.equal(payload.retry_reason, 'dispatch_run_cancelled');
  assert.equal(payload.issue_number, 207);
  assert.equal('action' in payload, false);
});

test('parseRetryDispatchArgs parses reconcile mode with defaults', () => {
  const args = parseRetryDispatchArgs(['node', 'script', 'reconcile']);
  assert.deepEqual(args, {
    mode: 'reconcile',
    repo: 'rick-chick/agrr',
  });
});

test('parseRetryDispatchArgs parses reconcile with retry-reason', () => {
  const args = parseRetryDispatchArgs([
    'node',
    'script',
    'reconcile',
    '--retry-reason',
    'dispatch_run_cancelled',
  ]);
  assert.equal(args.mode, 'reconcile');
  assert.equal(args.retryReason, 'dispatch_run_cancelled');
});

test('parseRetryDispatchArgs parses issue number mode', () => {
  const args = parseRetryDispatchArgs(['node', 'script', 'issue', '--number', '42']);
  assert.equal(args.mode, 'issue');
  assert.equal(args.number, '42');
  assert.equal(args.repo, 'rick-chick/agrr');
});

test('defaultRetryReasonForMode maps automation entry points', () => {
  assert.equal(defaultRetryReasonForMode('reconcile'), 'scheduled_reconcile');
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
      issueLabels: 'agent-ready,agent-blocked',
      hasOpenFixPr: false,
    }),
    { eligible: true, action: 'implement' },
  );
});

test('isRetryCandidate rejects only agent-in-progress among stop labels', () => {
  assert.equal(
    isRetryCandidate({
      issueLabels: 'agent-ready,agent-in-progress',
      hasOpenFixPr: false,
    }).reason,
    'has agent-in-progress',
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
  // Draft PR + CI failure gap (#354): Issue Worker must not re-dispatch implement;
  // PR Merge Worker ci_fix / retry reconcile owns recovery on the existing PR branch.
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

test('resolveDependencyGate passes when all dependencies are closed', async () => {
  const body = ['## 依存', '', '- #317'].join('\n');
  const result = await resolveDependencyGate({
    issueNumber: 318,
    issueBody: body,
    getAgentDepsContract: async () => agentContract([317], body),
    fetchIssueState: async (number) => (number === 317 ? 'CLOSED' : 'OPEN'),
  });
  assert.deepEqual(result, { skip: false });
});

test('resolveDependencyGate blocks when a dependency is open', async () => {
  const body = ['## 依存', '', '- #317'].join('\n');
  const result = await resolveDependencyGate({
    issueNumber: 318,
    issueBody: body,
    getAgentDepsContract: async () => agentContract([317], body),
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
        getAgentDepsContract: async (number, currentBody) =>
          agentContract(number === 318 ? [317] : [318], currentBody),
        fetchIssueState: async () => 'OPEN',
        fetchIssueBody: async (number) => bodies[number] ?? '',
      }),
    /circular dependency/i,
  );
});

test('resolveDependencyGate blocks when agent cache is missing', async () => {
  const body = ['## 依存', '', '- #317'].join('\n');
  const result = await resolveDependencyGate({
    issueNumber: 318,
    issueBody: body,
    getAgentDepsContract: async () => null,
    fetchIssueState: async () => 'OPEN',
  });
  assert.deepEqual(result, {
    skip: true,
    skipReason: 'agent dependency cache missing or stale for #318',
    openDependencies: [],
  });
});

test('resolveDependencyGate blocks when agent cache getter is unavailable', async () => {
  const body = ['## 依存', '', '- #317'].join('\n');
  const result = await resolveDependencyGate({
    issueNumber: 318,
    issueBody: body,
    fetchIssueState: async () => 'OPEN',
  });
  assert.deepEqual(result, {
    skip: true,
    skipReason: 'agent dependency cache unavailable',
    openDependencies: [],
  });
});

test('resolveDependencyGateFromAgentCache uses agent hard_dependencies only (#384 type)', async () => {
  const body = [
    '## 依存',
    '',
    '- なし（既存 open issue #362 epic「作業予定画面」とは独立）',
  ].join('\n');
  const result = await resolveDependencyGateFromAgentCache({
    issueNumber: 384,
    issueBody: body,
    getAgentDepsContract: async () => agentContract([], body),
    fetchIssueState: async () => 'OPEN',
  });
  assert.deepEqual(result, { skip: false });
});

test('resolveDependencyGateFromAgentCache blocks #402 type when #384 is open', async () => {
  const body = ['## 依存', '', '- #384（タブラベル整合。open の間は着手不可）'].join('\n');
  const result = await resolveDependencyGateFromAgentCache({
    issueNumber: 402,
    issueBody: body,
    getAgentDepsContract: async () => agentContract([384], body),
    fetchIssueState: async (number) => (number === 384 ? 'OPEN' : 'CLOSED'),
  });
  assert.deepEqual(result, {
    skip: true,
    skipReason: 'dependency #384 is open',
    openDependencies: [384],
  });
});

test('resolveDependencyGateFromAgentCache blocks stale body_hash', async () => {
  const body = ['## 依存', '', '- #317'].join('\n');
  const result = await resolveDependencyGateFromAgentCache({
    issueNumber: 318,
    issueBody: body,
    getAgentDepsContract: async () => ({
      hard_dependencies: [317],
      soft_notes: [],
      rationale: 'stale',
      body_hash: 'deadbeef',
    }),
    fetchIssueState: async () => 'OPEN',
  });
  assert.deepEqual(result, {
    skip: true,
    skipReason: 'agent dependency cache missing or stale for #318',
    openDependencies: [],
  });
});

test('dispatch lib does not export dependency parsers', async () => {
  const source = await readFile(new URL('./issue-worker-dispatch-lib.mjs', import.meta.url), 'utf8');
  assert.doesNotMatch(source, /export function parseHardDependencyIssueNumbers/);
  assert.doesNotMatch(source, /export function parseDependencyIssueNumbers/);
  assert.doesNotMatch(source, /parseHardDependencyIssueNumbers/);
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

test('resolveEpicImplementGate delegates to resolveEpicDispatchAction', () => {
  assert.deepEqual(
    resolveEpicImplementGate({
      action: 'implement',
      issueTitle: '[epic] Parent issue',
      issueLabels: '',
    }),
    { action: 'epic_close_check' },
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

test('formatDependencyGateComment includes open dependency numbers', () => {
  const comment = formatDependencyGateComment([317, 320]);
  assert.match(comment, /#317/);
  assert.match(comment, /#320/);
  assert.match(comment, /dispatch 保留/);
});

test('resolvePreDispatchGates allows epic_close_check without dependency cache', async () => {
  const result = await resolvePreDispatchGates({
    action: 'epic_close_check',
    issueNumber: 362,
    issueTitle: '[epic] Parent',
    issueBody: '## 子 Issue\n\n- #363',
    issueLabels: 'agent-ready',
    fetchIssueState: async () => 'OPEN',
    fetchIssueBody: async () => '',
  });
  assert.deepEqual(result, { skip: false });
});

test('resolveImplementPreDispatchGates blocks open dependencies', async () => {
  const body = '## 依存\n\n- #317';
  const result = await resolveImplementPreDispatchGates({
    issueNumber: 318,
    issueTitle: 'Child',
    issueBody: body,
    issueLabels: 'agent-ready',
    getAgentDepsContract: async () => agentContract([317], body),
    fetchIssueState: async (number) => (number === 317 ? 'OPEN' : 'CLOSED'),
  });
  assert.equal(result.skip, true);
  assert.match(result.skipReason, /dependency #317 is open/);
});

test('isEpicCloseCheckCandidate does not require agent-ready', () => {
  const result = isEpicCloseCheckCandidate({
    issueTitle: '[epic] Parent',
    issueLabels: 'agent-skipped',
    hasOpenFixPr: false,
  });
  assert.deepEqual(result, { eligible: true, action: 'epic_close_check' });
});

test('selectDispatchableOnDependencyClosed dispatches when agent cache links closed dependency', async () => {
  const body = '## 依存\n\n- #364';
  const getAgentDepsContract = async (_number, currentBody) => agentContract([364], currentBody);
  const selected = await selectDispatchableOnDependencyClosed(
    [
      {
        number: 370,
        title: 'Child',
        labels: ['agent-ready'],
        body,
      },
    ],
    364,
    () => false,
    getAgentDepsContract,
    async () => ({ skip: false }),
  );
  assert.deepEqual(selected, {
    issue: {
      number: 370,
      title: 'Child',
      labels: ['agent-ready'],
      body,
    },
    action: 'implement',
  });
});

test('selectDispatchableOnDependencyClosed skips when dependency is not in agent cache', async () => {
  const body = '## 依存\n\n- #364';
  const selected = await selectDispatchableOnDependencyClosed(
    [
      {
        number: 370,
        title: 'Child',
        labels: ['agent-ready'],
        body,
      },
    ],
    364,
    () => false,
    async () => null,
    async () => ({ skip: false }),
  );
  assert.equal(selected, null);
});

test('resolveHardDependencies reads agent cache only', async () => {
  const body = '## 依存\n\n- #364';
  const result = await resolveHardDependencies({
    issueNumber: 370,
    issueBody: body,
    getAgentDepsContract: async () => agentContract([365], body),
  });
  assert.deepEqual(result, {
    hardDependencies: [365],
    source: 'cache',
  });
});

test('resolveHardDependencies returns miss when cache is missing', async () => {
  const body = '## 依存\n\n- #364';
  const result = await resolveHardDependencies({
    issueNumber: 370,
    issueBody: body,
    getAgentDepsContract: async () => null,
  });
  assert.deepEqual(result, { source: 'miss' });
});

test('collectReconcileDispatchCandidates skips pre-dispatch failure and includes next issue', async () => {
  const issues = [
    {
      number: 384,
      title: 'blocked',
      labels: ['agent-ready'],
      body: '## 依存\n\n- #362',
    },
    {
      number: 398,
      title: 'ready',
      labels: ['agent-ready'],
      body: '## 依存\n\n- なし',
    },
  ];
  const candidates = await collectReconcileDispatchCandidates(
    [],
    issues,
    () => false,
    async (issue) => {
      if (issue.number === 384) {
        return { skip: true, skipReason: 'dependency #362 is open' };
      }
      return { skip: false };
    },
  );
  assert.deepEqual(candidates, [
    {
      issue: issues[1],
      action: 'implement',
    },
  ]);
});

test('collectReconcileDispatchCandidates returns empty when no issue passes gates', async () => {
  const issues = [
    { number: 384, title: 'blocked', labels: ['agent-ready'], body: '' },
    { number: 398, title: 'blocked2', labels: ['agent-ready'], body: '' },
  ];
  const candidates = await collectReconcileDispatchCandidates(
    [],
    issues,
    () => false,
    async () => ({ skip: true, skipReason: 'blocked' }),
  );
  assert.deepEqual(candidates, []);
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

test('parseDispatchedIssueNumberFromLog returns last dispatch number', () => {
  const log = [
    'setup',
    'Dispatched Delivery Agent for #316 (scheduled_reconcile)',
    'Dispatched Delivery Agent for #323 (scheduled_reconcile)',
  ].join('\n');
  assert.equal(parseDispatchedIssueNumberFromLog(log), 323);
});

test('parseDispatchedIssueNumberFromLog returns null when no dispatch line', () => {
  assert.equal(parseDispatchedIssueNumberFromLog('no dispatch here'), null);
});

test('collectReconcileDispatchCandidates does not duplicate agent-ready epic', async () => {
  const epic = {
    number: 316,
    title: '[epic] Parent',
    labels: ['agent-ready'],
    body: '## 子 Issue\n\n- #323',
  };
  const candidates = await collectReconcileDispatchCandidates(
    [],
    [epic],
    () => false,
    async () => ({ skip: false }),
  );
  assert.equal(candidates.length, 1);
  assert.equal(candidates[0].issue.number, 316);
  assert.equal(candidates[0].action, 'epic_close_check');
});

test('collectReconcileDispatchCandidates includes epic without agent-ready and implement', async () => {
  const candidates = await collectReconcileDispatchCandidates(
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
    async () => ({ skip: false }),
  );
  assert.equal(candidates.length, 2);
  const actions = candidates.map((entry) => `${entry.issue.number}:${entry.action}`);
  assert.deepEqual(actions, ['362:epic_close_check', '323:implement']);
});

test('resolveOnClosedDispatch skips when no dependency link', () => {
  const result = resolveOnClosedDispatch(null);
  assert.deepEqual(result, {
    dispatch: false,
    reason: 'no dependency-unblocked agent-ready issue',
  });
});

test('resolveOnClosedDispatch dispatches dependency-selected issue', () => {
  const selected = {
    issue: { number: 370 },
    action: 'implement',
  };
  assert.deepEqual(resolveOnClosedDispatch(selected), {
    dispatch: true,
    selected,
  });
});
