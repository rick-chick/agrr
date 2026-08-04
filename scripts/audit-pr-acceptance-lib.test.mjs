import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  auditLinkedPrAcceptance,
  auditParentIssueCloseEligibility,
} from './audit-pr-acceptance-lib.mjs';

test('auditLinkedPrAcceptance keeps parent open when follow-up is open', () => {
  const result = auditLinkedPrAcceptance({
    followUpIssues: [
      { number: 500, state: 'OPEN', labels: ['acceptance-follow-up'] },
    ],
  });
  assert.equal(result.mergeAllowed, true);
  assert.equal(result.closeParentAllowed, false);
  assert.match(result.reasons[0], /#500/);
});

test('auditLinkedPrAcceptance allows parent close when follow-ups closed', () => {
  const result = auditLinkedPrAcceptance({
    followUpIssues: [
      { number: 500, state: 'CLOSED', labels: ['acceptance-follow-up'] },
    ],
  });
  assert.equal(result.mergeAllowed, true);
  assert.equal(result.closeParentAllowed, true);
});

test('auditLinkedPrAcceptance allows close when no follow-up tracking', () => {
  const result = auditLinkedPrAcceptance({ followUpIssues: [] });
  assert.equal(result.mergeAllowed, true);
  assert.equal(result.closeParentAllowed, true);
});

test('auditLinkedPrAcceptance ignores issues without acceptance-follow-up label', () => {
  const result = auditLinkedPrAcceptance({
    followUpIssues: [{ number: 501, state: 'OPEN', labels: ['agent-ready'] }],
  });
  assert.equal(result.closeParentAllowed, true);
});

test('auditParentIssueCloseEligibility waits for open follow-ups', () => {
  const result = auditParentIssueCloseEligibility({
    followUpIssues: [
      { number: 500, state: 'OPEN', labels: ['acceptance-follow-up'] },
    ],
  });
  assert.equal(result.closeAllowed, false);
});

test('auditParentIssueCloseEligibility closes when follow-ups done', () => {
  const result = auditParentIssueCloseEligibility({
    followUpIssues: [
      { number: 500, state: 'CLOSED', labels: ['acceptance-follow-up'] },
    ],
  });
  assert.equal(result.closeAllowed, true);
});

test('auditParentIssueCloseEligibility allows close without follow-up label issues', () => {
  const result = auditParentIssueCloseEligibility({
    followUpIssues: [{ number: 500, state: 'OPEN', labels: ['agent-ready'] }],
  });
  assert.equal(result.closeAllowed, true);
});

test('auditParentIssueCloseEligibility allows close when no follow-ups tracked', () => {
  const result = auditParentIssueCloseEligibility({ followUpIssues: [] });
  assert.equal(result.closeAllowed, true);
});
