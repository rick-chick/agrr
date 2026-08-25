import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  REQUIRED_CI_CONTEXTS,
  REQUIRED_WHEN_PRESENT_CI_CONTEXTS,
  areRequiredChecksComplete,
  areRequiredChecksGreen,
  classifyRequiredCiState,
  canMarkReady,
  isEligibleAgentPr,
  isNonFatalMarkReadyError,
  resolveGhToken,
  selectDraftPrNumberToReady,
  shouldReceiveAgentMergeLabel,
  sortedEligibleDraftNumbers,
} from './pr-agent-prep-lib.mjs';

const BASE_META = {
  authorLogin: 'cursor[bot]',
  baseRefName: 'master',
  headRefName: 'cursor/issue-worker-abc',
  labels: [],
  headOwner: 'rick-chick',
  baseOwner: 'rick-chick',
};

test('shouldReceiveAgentMergeLabel requires closingIssuesReferences via API count', () => {
  assert.equal(shouldReceiveAgentMergeLabel({ closingIssueCount: 1 }), true);
  assert.equal(shouldReceiveAgentMergeLabel({ closingIssueCount: 0 }), false);
});

test('isEligibleAgentPr accepts cursor/* from cursor bot', () => {
  assert.equal(isEligibleAgentPr(BASE_META), true);
});

test('isEligibleAgentPr accepts issue/* from cursor bot', () => {
  assert.equal(
    isEligibleAgentPr({ ...BASE_META, headRefName: 'issue/42-fix-foo' }),
    true,
  );
});

test('isEligibleAgentPr rejects non-opt-in branch even with agent author', () => {
  assert.equal(
    isEligibleAgentPr({
      ...BASE_META,
      authorLogin: 'rick-chick',
      headRefName: 'feature/manual',
    }),
    false,
  );
});

test('isEligibleAgentPr accepts cursor/* from non-cursor author on same repo', () => {
  assert.equal(
    isEligibleAgentPr({
      ...BASE_META,
      authorLogin: 'rick-chick',
      headRefName: 'cursor/task-schedule-list-from-work-hub',
    }),
    true,
  );
});

test('isEligibleAgentPr rejects non-opt-in cursor PR', () => {
  assert.equal(
    isEligibleAgentPr({ ...BASE_META, headRefName: 'feature/not-agent' }),
    false,
  );
});

test('isEligibleAgentPr rejects fork PR', () => {
  assert.equal(
    isEligibleAgentPr({ ...BASE_META, headOwner: 'fork-user' }),
    false,
  );
});

test('isEligibleAgentPr ignores merge-prohibition labels', () => {
  assert.equal(
    isEligibleAgentPr({ ...BASE_META, labels: ['agent-no-merge', 'do-not-merge', 'wip'] }),
    true,
  );
});

test('canMarkReady requires draft, empty queue, and green CI', () => {
  assert.equal(
    canMarkReady({
      isDraft: true,
      openReadyAgentMergeCount: 0,
      requiredChecksGreen: true,
    }),
    true,
  );
  assert.equal(
    canMarkReady({
      isDraft: true,
      openReadyAgentMergeCount: 1,
      requiredChecksGreen: true,
    }),
    false,
  );
  assert.equal(
    canMarkReady({
      isDraft: false,
      openReadyAgentMergeCount: 0,
      requiredChecksGreen: true,
    }),
    false,
  );
});

test('sortedEligibleDraftNumbers returns all eligible drafts in ascending order', () => {
  assert.deepEqual(
    sortedEligibleDraftNumbers(
      [
        { number: 210, isDraft: true, eligible: true },
        { number: 208, isDraft: true, eligible: true },
        { number: 209, isDraft: false, eligible: true },
      ],
      0,
    ),
    [208, 210],
  );
});

test('resolveGhToken prefers AGRR_GH_PAT over GITHUB_TOKEN', () => {
  assert.equal(
    resolveGhToken({
      agrrGhPat: 'github_pat_example',
      ghToken: 'ghs_actions',
      githubToken: 'ghs_fallback',
    }),
    'github_pat_example',
  );
});

test('selectDraftPrNumberToReady picks lowest eligible draft', () => {
  assert.equal(
    selectDraftPrNumberToReady(
      [
        { number: 177, isDraft: true, eligible: true },
        { number: 173, isDraft: true, eligible: true },
      ],
      0,
    ),
    173,
  );
});

test('selectDraftPrNumberToReady returns null when queue is blocked', () => {
  assert.equal(
    selectDraftPrNumberToReady(
      [{ number: 177, isDraft: true, eligible: true }],
      1,
    ),
    null,
  );
});

test('isNonFatalMarkReadyError matches GITHUB_TOKEN integration permission errors', () => {
  assert.equal(
    isNonFatalMarkReadyError(
      'GraphQL: Resource not accessible by integration (markPullRequestReadyForReview)',
    ),
    true,
  );
  assert.equal(isNonFatalMarkReadyError('unexpected gh failure'), false);
});

const BASE_REQUIRED_CHECKS = [
  { name: 'rails-test', state: 'SUCCESS' },
  { name: 'frontend-test', state: 'SUCCESS' },
  { name: 'lint / frontend-lint', state: 'SUCCESS' },
  { name: 'lint / run-architecture-guard', state: 'SUCCESS' },
];

test('REQUIRED_CI_CONTEXTS includes frontend-e2e-smoke', () => {
  assert.ok(REQUIRED_CI_CONTEXTS.includes('frontend-e2e-smoke'));
});

test('frontend-e2e-smoke is required only when present on PR', () => {
  assert.deepEqual(REQUIRED_WHEN_PRESENT_CI_CONTEXTS, ['frontend-e2e-smoke']);
});

test('areRequiredChecksGreen requires ruleset contexts', () => {
  assert.equal(areRequiredChecksGreen(BASE_REQUIRED_CHECKS), true);
  assert.equal(
    areRequiredChecksGreen([
      ...BASE_REQUIRED_CHECKS,
      { name: 'frontend-e2e-smoke', state: 'SUCCESS' },
    ]),
    true,
  );
  assert.equal(
    areRequiredChecksGreen([
      { name: 'rails-test', state: 'SUCCESS' },
      { name: 'frontend-test', state: 'PENDING' },
      { name: 'lint / frontend-lint', state: 'SUCCESS' },
      { name: 'lint / run-architecture-guard', state: 'SUCCESS' },
    ]),
    false,
  );
});

test('areRequiredChecksGreen fails when frontend-e2e-smoke failed', () => {
  assert.equal(
    areRequiredChecksGreen([
      ...BASE_REQUIRED_CHECKS,
      { name: 'frontend-e2e-smoke', state: 'FAILURE' },
    ]),
    false,
  );
});

test('areRequiredChecksGreen passes when frontend-e2e-smoke absent (path filter)', () => {
  assert.equal(areRequiredChecksGreen(BASE_REQUIRED_CHECKS), true);
});

test('areRequiredChecksComplete is false while any required check is pending', () => {
  assert.equal(
    areRequiredChecksComplete([
      { name: 'rails-test', state: 'SUCCESS' },
      { name: 'frontend-test', state: 'PENDING' },
      { name: 'lint / frontend-lint', state: 'SUCCESS' },
      { name: 'lint / run-architecture-guard', state: 'SUCCESS' },
    ]),
    false,
  );
  assert.equal(
    areRequiredChecksComplete([
      { name: 'rails-test', state: 'SUCCESS' },
      { name: 'frontend-test', state: 'FAILURE' },
      { name: 'lint / frontend-lint', state: 'SUCCESS' },
      { name: 'lint / run-architecture-guard', state: 'SUCCESS' },
    ]),
    true,
  );
});

test('areRequiredChecksComplete ignores absent frontend-e2e-smoke', () => {
  assert.equal(areRequiredChecksComplete(BASE_REQUIRED_CHECKS), true);
  assert.equal(
    areRequiredChecksComplete([
      ...BASE_REQUIRED_CHECKS,
      { name: 'frontend-e2e-smoke', state: 'IN_PROGRESS' },
    ]),
    false,
  );
});

test('classifyRequiredCiState maps checks to incomplete, failed, or green', () => {
  assert.equal(
    classifyRequiredCiState([
      { name: 'rails-test', state: 'SUCCESS' },
      { name: 'frontend-test', state: 'IN_PROGRESS' },
      { name: 'lint / frontend-lint', state: 'SUCCESS' },
      { name: 'lint / run-architecture-guard', state: 'SUCCESS' },
    ]),
    'incomplete',
  );
  assert.equal(
    classifyRequiredCiState([
      { name: 'rails-test', state: 'SUCCESS' },
      { name: 'frontend-test', state: 'FAILURE' },
      { name: 'lint / frontend-lint', state: 'SUCCESS' },
      { name: 'lint / run-architecture-guard', state: 'SUCCESS' },
    ]),
    'failed',
  );
  assert.equal(
    classifyRequiredCiState(BASE_REQUIRED_CHECKS),
    'green',
  );
  assert.equal(
    classifyRequiredCiState([
      ...BASE_REQUIRED_CHECKS,
      { name: 'frontend-e2e-smoke', state: 'FAILURE' },
    ]),
    'failed',
  );
});
