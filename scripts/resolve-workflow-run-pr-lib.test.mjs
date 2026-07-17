import assert from 'node:assert/strict';
import { test } from 'node:test';

import { mapWorkflowRunPrFields, resolveWorkflowRunPr } from './resolve-workflow-run-pr-lib.mjs';

const HEAD_SHA = 'abc123deadbeef';

test('resolveWorkflowRunPr succeeds when commits/pulls returns one open PR', () => {
  const result = resolveWorkflowRunPr({
    headSha: HEAD_SHA,
    fetchCommitPulls: () => [{ number: 42, state: 'open', title: 'Fix bug' }],
    fetchPrView: () => {
      throw new Error('fetchPrView should not be called');
    },
    fetchPrListByHeadOid: () => {
      throw new Error('fetchPrListByHeadOid should not be called');
    },
  });

  assert.equal(result.skip, false);
  assert.equal(result.pr.number, 42);
});

test('resolveWorkflowRunPr falls back to workflowRunPullRequests when commits/pulls throws', () => {
  let prViewCalled = false;
  const result = resolveWorkflowRunPr({
    headSha: HEAD_SHA,
    workflowRunPullRequests: [{ number: 99 }],
    fetchCommitPulls: () => {
      throw new Error("invalid character '<' looking for beginning of value");
    },
    fetchPrView: (number) => {
      prViewCalled = true;
      assert.equal(number, 99);
      return { number: 99, state: 'open', title: 'From workflow_run' };
    },
    fetchPrListByHeadOid: () => {
      throw new Error('fetchPrListByHeadOid should not be called');
    },
  });

  assert.equal(prViewCalled, true);
  assert.equal(result.skip, false);
  assert.equal(result.pr.number, 99);
});

test('resolveWorkflowRunPr falls back to fetchPrListByHeadOid when commits/pulls is empty', () => {
  let listCalled = false;
  const result = resolveWorkflowRunPr({
    headSha: HEAD_SHA,
    workflowRunPullRequests: [],
    fetchCommitPulls: () => [],
    fetchPrListByHeadOid: (sha) => {
      listCalled = true;
      assert.equal(sha, HEAD_SHA);
      return [{ number: 7, state: 'open', headRefOid: HEAD_SHA }];
    },
  });

  assert.equal(listCalled, true);
  assert.equal(result.skip, false);
  assert.equal(result.pr.number, 7);
});

test('resolveWorkflowRunPr skips when multiple open PRs are found', () => {
  const result = resolveWorkflowRunPr({
    headSha: HEAD_SHA,
    fetchCommitPulls: () => [
      { number: 1, state: 'open' },
      { number: 2, state: 'open' },
    ],
  });

  assert.equal(result.skip, true);
  assert.match(result.skipReason, /Multiple open PRs/);
});

test('resolveWorkflowRunPr skips when no PR is found', () => {
  const result = resolveWorkflowRunPr({
    headSha: HEAD_SHA,
    workflowRunPullRequests: [],
    fetchCommitPulls: () => [],
    fetchPrListByHeadOid: () => [],
  });

  assert.equal(result.skip, true);
  assert.match(result.skipReason, /No open PR found/);
});

test('resolveWorkflowRunPr rejects closed PR from fetchPrView and falls back to fetchPrListByHeadOid', () => {
  let listCalled = false;
  const result = resolveWorkflowRunPr({
    headSha: HEAD_SHA,
    workflowRunPullRequests: [{ number: 88 }],
    fetchCommitPulls: () => [],
    fetchPrView: (number) => {
      assert.equal(number, 88);
      return { number: 88, state: 'closed', title: 'Merged PR' };
    },
    fetchPrListByHeadOid: (sha) => {
      listCalled = true;
      assert.equal(sha, HEAD_SHA);
      return [{ number: 88, state: 'open', headRefOid: HEAD_SHA }];
    },
  });

  assert.equal(listCalled, true);
  assert.equal(result.skip, false);
  assert.equal(result.pr.number, 88);
});

test('resolveWorkflowRunPr skips when fetchPrView returns closed PR and no other PR is found', () => {
  const result = resolveWorkflowRunPr({
    headSha: HEAD_SHA,
    workflowRunPullRequests: [{ number: 77 }],
    fetchCommitPulls: () => [],
    fetchPrView: () => ({ number: 77, state: 'closed' }),
    fetchPrListByHeadOid: () => [],
  });

  assert.equal(result.skip, true);
  assert.match(result.skipReason, /No open PR found/);
});

test('resolveWorkflowRunPr falls back to fetchPrListByHeadOid when fetchPrView throws', () => {
  let listCalled = false;
  const result = resolveWorkflowRunPr({
    headSha: HEAD_SHA,
    workflowRunPullRequests: [{ number: 55 }],
    fetchCommitPulls: () => [],
    fetchPrView: () => {
      throw new Error('gh pr view failed');
    },
    fetchPrListByHeadOid: (sha) => {
      listCalled = true;
      assert.equal(sha, HEAD_SHA);
      return [{ number: 55, state: 'open', headRefOid: HEAD_SHA }];
    },
  });

  assert.equal(listCalled, true);
  assert.equal(result.skip, false);
  assert.equal(result.pr.number, 55);
});

test('mapWorkflowRunPrFields maps REST-shaped PR object', () => {
  const mapped = mapWorkflowRunPrFields({
    number: 42,
    head: { ref: 'feature/foo' },
    body: 'PR body',
    title: 'Fix bug',
    labels: [{ name: 'bug' }, { name: 'agent-ready' }],
    html_url: 'https://github.com/org/repo/pull/42',
    user: { login: 'alice' },
  });

  assert.deepEqual(mapped, {
    number: 42,
    headRef: 'feature/foo',
    body: 'PR body',
    title: 'Fix bug',
    labels: 'bug,agent-ready',
    url: 'https://github.com/org/repo/pull/42',
    author: 'alice',
  });
});

test('mapWorkflowRunPrFields maps GraphQL-shaped PR object', () => {
  const mapped = mapWorkflowRunPrFields({
    number: 99,
    headRefName: 'cursor/issue-1',
    body: '',
    title: 'GraphQL PR',
    labels: ['agent-merge', 'ready'],
    url: 'https://github.com/org/repo/pull/99',
    author: { login: 'bot' },
  });

  assert.deepEqual(mapped, {
    number: 99,
    headRef: 'cursor/issue-1',
    body: '',
    title: 'GraphQL PR',
    labels: 'agent-merge,ready',
    url: 'https://github.com/org/repo/pull/99',
    author: 'bot',
  });
});
