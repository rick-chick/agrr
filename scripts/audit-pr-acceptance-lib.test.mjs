import assert from 'node:assert/strict';
import { test } from 'node:test';

import {
  auditLinkedPrAcceptance,
  auditParentIssueCloseEligibility,
  completionLineIsIncomplete,
  completionLineIsSatisfied,
  countUncheckedRequiredCheckboxes,
  extractFollowUpIssueNumbers,
  extractParentIssueNumber,
  parsePrCompletionSection,
  prBodyClaimsClosesIssue,
} from './audit-pr-acceptance-lib.mjs';

const PARTIAL_PR = `## Issue
Part of #462

## 完了条件（issue より）
- [x] C1: pending → fetching — contract GREEN
- [ ] C3–C5: 取得完了・UI・チャート — 未カバー
Follow-up: #500
`;

const COMPLETE_PR = `## Issue
Part of #462

## 完了条件（issue より）
- [x] C1: pending → fetching — contract GREEN
- [x] C3: completed — e2e GREEN
`;

test('parsePrCompletionSection extracts checkbox lines from completion section', () => {
  const { lines, hasSection } = parsePrCompletionSection(`
## Issue
Part of #462

## 完了条件（issue より）
- [x] C1: pending → fetching
- [ ] C3: chart — 未カバー

## テスト
- [x] contract GREEN
`);
  assert.equal(hasSection, true);
  assert.equal(lines.length, 2);
  assert.match(lines[0], /C1/);
});

test('countUncheckedRequiredCheckboxes counts open boxes in parent body', () => {
  assert.equal(
    countUncheckedRequiredCheckboxes('- [ ] C3\n- [x] C1\n- [ ] C4'),
    2,
  );
  assert.equal(countUncheckedRequiredCheckboxes('- [x] all done'), 0);
});

test('prBodyClaimsClosesIssue detects Closes and Fixes', () => {
  assert.equal(prBodyClaimsClosesIssue('Closes #462'), true);
  assert.equal(prBodyClaimsClosesIssue('Fixes #462'), true);
  assert.equal(prBodyClaimsClosesIssue('Part of #462'), false);
});

test('extractFollowUpIssueNumbers parses Follow-up lines', () => {
  assert.deepEqual(extractFollowUpIssueNumbers(PARTIAL_PR), [500]);
  assert.deepEqual(extractFollowUpIssueNumbers('follow-up: #12\nFollow-up: #34'), [
    12, 34,
  ]);
});

test('completion line helpers', () => {
  assert.equal(
    completionLineIsSatisfied('- [x] C1: ok — test GREEN'),
    true,
  );
  assert.equal(
    completionLineIsIncomplete('- [ ] C3: 未カバー'),
    true,
  );
});

test('auditLinkedPrAcceptance blocks Closes in PR body', () => {
  const result = auditLinkedPrAcceptance({
    prBody: 'Closes #462\n\n## 完了条件\n- [x] all',
  });
  assert.equal(result.mergeAllowed, false);
});

test('auditLinkedPrAcceptance blocks incomplete without follow-up', () => {
  const result = auditLinkedPrAcceptance({
    prBody: `Part of #462\n\n## 完了条件\n- [ ] C3 — 未カバー`,
  });
  assert.equal(result.mergeAllowed, false);
});

test('auditLinkedPrAcceptance allows partial merge with follow-up', () => {
  const result = auditLinkedPrAcceptance({
    prBody: PARTIAL_PR,
    followUpIssues: [{ number: 500, state: 'OPEN' }],
  });
  assert.equal(result.mergeAllowed, true);
  assert.equal(result.closeParentAllowed, false);
});

test('auditLinkedPrAcceptance allows parent close when complete', () => {
  const result = auditLinkedPrAcceptance({
    prBody: COMPLETE_PR,
    followUpIssues: [],
  });
  assert.equal(result.mergeAllowed, true);
  assert.equal(result.closeParentAllowed, true);
});

test('extractParentIssueNumber reads Parent header', () => {
  assert.equal(extractParentIssueNumber('Parent: #462\n\nCriteria: C3'), 462);
  assert.equal(extractParentIssueNumber('no parent'), null);
});

test('auditParentIssueCloseEligibility waits for open follow-ups', () => {
  const result = auditParentIssueCloseEligibility({
    parentBody: '- [ ] C3\n- [ ] C4',
    followUpIssues: [
      { number: 500, state: 'OPEN', labels: ['acceptance-follow-up'] },
    ],
  });
  assert.equal(result.closeAllowed, false);
});

test('auditParentIssueCloseEligibility closes when follow-ups done', () => {
  const result = auditParentIssueCloseEligibility({
    parentBody: '- [ ] C3\n- [ ] C4',
    followUpIssues: [
      { number: 500, state: 'CLOSED', labels: ['acceptance-follow-up'] },
    ],
  });
  assert.equal(result.closeAllowed, true);
});
