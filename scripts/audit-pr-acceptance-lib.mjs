/**
 * Agent-only acceptance audit helpers.
 * Invoke from Merge Worker / Delivery Agent SKILL — not from dispatch lib or workflow bash.
 */

const CLOSES_PATTERN = /(?:^|\n)\s*(?:Closes|Fixes)\s+#\d+/im;
const FOLLOW_UP_PATTERN = /(?:follow-up|Follow-up):\s*#(\d+)/gi;
const INCOMPLETE_MARKERS = /未カバー|手動未実施/;
const UNCHECKED_BOX = /-\s*\[\s*\]/;
const CHECKED_BOX = /-\s*\[x\]/i;
const PRODUCTION_OUT_OF_SCOPE =
  /本番確認|agrr\.net|本番デプロイ|本番\s*DB|本番\s*LB|本番\s*Cloud\s*Run|Cloud\s*Run\s*本番|本番\s*GCS|GCS\s*本番|本番で確認|gcloud\s*観測|Litestream|本番.*curl|curl.*本番/i;
const PRODUCTION_POLICY_NEGATION =
  /本番確認.*(含めない|書かない|禁止)|(含めない|書かない|禁止).*本番確認/;

/**
 * @param {string} line
 */
export function completionLineIsAutomationOutOfScope(line) {
  const text = line ?? '';
  if (/Automation\s*対象外（本番確認）/.test(text)) {
    return true;
  }
  if (PRODUCTION_POLICY_NEGATION.test(text)) {
    return false;
  }
  return PRODUCTION_OUT_OF_SCOPE.test(text);
}

/**
 * @param {string} text
 */
export function filterAutomationScopedCheckboxLines(text) {
  return (text ?? '')
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.startsWith('-'))
    .filter((line) => !completionLineIsAutomationOutOfScope(line));
}

/**
 * @param {string} text
 * @returns {number[]}
 */
export function extractFollowUpIssueNumbers(text) {
  const numbers = new Set();
  for (const match of text.matchAll(FOLLOW_UP_PATTERN)) {
    numbers.add(Number(match[1]));
  }
  return [...numbers].sort((a, b) => a - b);
}

/**
 * @param {string} prBody
 */
export function prBodyClaimsClosesIssue(prBody) {
  return CLOSES_PATTERN.test(prBody ?? '');
}

/**
 * @param {string} prBody
 * @returns {{ lines: string[]; hasSection: boolean }}
 */
export function parsePrCompletionSection(prBody) {
  const match = (prBody ?? '').match(
    /##\s*完了条件[^\n]*\n([\s\S]*?)(?=\n## |\s*$)/i,
  );
  if (!match) {
    return { lines: [], hasSection: false };
  }
  const lines = match[1]
    .split('\n')
    .map((line) => line.trim())
    .filter((line) => line.startsWith('-'));
  return { lines, hasSection: true };
}

/**
 * @param {string} line
 */
export function completionLineIsIncomplete(line) {
  if (completionLineIsAutomationOutOfScope(line)) {
    return false;
  }
  return UNCHECKED_BOX.test(line) || INCOMPLETE_MARKERS.test(line);
}

/**
 * @param {string} line
 */
export function completionLineIsSatisfied(line) {
  return CHECKED_BOX.test(line) && !completionLineIsIncomplete(line);
}

/**
 * @param {string} issueBody
 * @returns {number}
 */
export function countUncheckedRequiredCheckboxes(issueBody) {
  return filterAutomationScopedCheckboxLines(issueBody).filter((line) =>
    UNCHECKED_BOX.test(line),
  ).length;
}

/**
 * @param {{
 *   prBody: string;
 *   followUpIssues?: Array<{ number: number; state: string }>;
 * }} input
 * @returns {{
 *   mergeAllowed: boolean;
 *   closeParentAllowed: boolean;
 *   reasons: string[];
 * }}
 */
export function auditLinkedPrAcceptance(input) {
  const reasons = [];
  const prBody = input.prBody ?? '';
  const followUpIssues = input.followUpIssues ?? [];

  if (prBodyClaimsClosesIssue(prBody)) {
    return {
      mergeAllowed: false,
      closeParentAllowed: false,
      reasons: ['PR must use Part of #N; Closes/Fixes is forbidden (Issue Worker §6)'],
    };
  }

  const { lines } = parsePrCompletionSection(prBody);
  const scopedLines = lines.filter((line) => !completionLineIsAutomationOutOfScope(line));
  const incompleteLines = scopedLines.filter(completionLineIsIncomplete);
  const followUpNumbers = extractFollowUpIssueNumbers(prBody);
  const openFollowUps = followUpIssues.filter((issue) => issue.state === 'OPEN');

  if (incompleteLines.length > 0) {
    const hasTrackedFollowUp =
      followUpNumbers.length > 0 || openFollowUps.length > 0;
    if (!hasTrackedFollowUp) {
      return {
        mergeAllowed: false,
        closeParentAllowed: false,
        reasons: [
          `Incomplete acceptance lines without Follow-up: #N (${incompleteLines.length})`,
        ],
      };
    }
  }

  const allListedSatisfied =
    scopedLines.length > 0 && scopedLines.every(completionLineIsSatisfied);
  const trackedFollowUps = followUpIssues.length > 0 ? followUpIssues : [];
  const allFollowUpsClosed =
    trackedFollowUps.length === 0 ||
    trackedFollowUps.every((issue) => issue.state === 'CLOSED');

  if (allListedSatisfied && incompleteLines.length === 0 && allFollowUpsClosed) {
    return {
      mergeAllowed: true,
      closeParentAllowed: true,
      reasons: ['All listed criteria satisfied; no open follow-ups'],
    };
  }

  return {
    mergeAllowed: true,
    closeParentAllowed: false,
    reasons: [
      'Partial completion: merge allowed; parent issue stays open until follow-ups close',
    ],
  };
}

/**
 * @param {string} issueBody
 * @returns {number | null}
 */
export function extractParentIssueNumber(issueBody) {
  const match = (issueBody ?? '').match(/(?:^|\n)\s*Parent:\s*#(\d+)/im);
  return match ? Number(match[1]) : null;
}

/**
 * @param {{
 *   parentBody: string;
 *   followUpIssues: Array<{ number: number; state: string; labels?: string[] }>;
 * }} input
 * @returns {{ closeAllowed: boolean; reasons: string[] }}
 */
export function auditParentIssueCloseEligibility(input) {
  const followUps = (input.followUpIssues ?? []).filter((issue) =>
    (issue.labels ?? []).includes('acceptance-follow-up'),
  );

  const openFollowUps = followUps.filter((issue) => issue.state === 'OPEN');
  if (openFollowUps.length > 0) {
    return {
      closeAllowed: false,
      reasons: [
        `Open acceptance-follow-up: ${openFollowUps.map((i) => `#${i.number}`).join(', ')}`,
      ],
    };
  }

  const unchecked = countUncheckedRequiredCheckboxes(input.parentBody ?? '');
  if (followUps.length > 0 && openFollowUps.length === 0) {
    return {
      closeAllowed: true,
      reasons: ['All acceptance-follow-up issues closed'],
    };
  }

  if (unchecked === 0) {
    return { closeAllowed: true, reasons: ['All parent checkboxes satisfied'] };
  }

  return {
    closeAllowed: false,
    reasons: [`Parent has ${unchecked} unchecked required checkbox(es)`],
  };
}
