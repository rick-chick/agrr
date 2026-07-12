import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  areRequiredChecksGreen,
  canMarkReady,
  isEligibleAgentPr,
  isNonFatalMarkReadyError,
  selectDraftPrNumberToReady,
} from './pr-agent-prep-lib.mjs';

const BASE_META = {
  authorLogin: 'cursor[bot]',
  baseRefName: 'master',
  headRefName: 'cursor/issue-worker-abc',
  body: '',
  labels: [],
  headOwner: 'rick-chick',
  baseOwner: 'rick-chick',
};

test('isEligibleAgentPr accepts cursor/* from cursor bot', () => {
  assert.equal(isEligibleAgentPr(BASE_META), true);
});

test('isEligibleAgentPr accepts issue/* from cursor bot', () => {
  assert.equal(
    isEligibleAgentPr({ ...BASE_META, headRefName: 'issue/42-fix-foo' }),
    true,
  );
});

test('isEligibleAgentPr accepts Merge-Strategy: agent for any author', () => {
  assert.equal(
    isEligibleAgentPr({
      ...BASE_META,
      authorLogin: 'rick-chick',
      headRefName: 'feature/manual',
      body: 'Merge-Strategy: agent',
    }),
    true,
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

test('isEligibleAgentPr rejects blocking labels', () => {
  assert.equal(
    isEligibleAgentPr({ ...BASE_META, labels: ['agent-no-merge'] }),
    false,
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

test('areRequiredChecksGreen requires ruleset contexts', () => {
  assert.equal(
    areRequiredChecksGreen([
      { name: 'rails-test', state: 'SUCCESS' },
      { name: 'frontend-test', state: 'SUCCESS' },
      { name: 'lint / frontend-lint', state: 'SUCCESS' },
    ]),
    true,
  );
  assert.equal(
    areRequiredChecksGreen([
      { name: 'rails-test', state: 'SUCCESS' },
      { name: 'frontend-test', state: 'PENDING' },
      { name: 'lint / frontend-lint', state: 'SUCCESS' },
    ]),
    false,
  );
});
