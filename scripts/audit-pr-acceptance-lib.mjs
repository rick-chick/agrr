/**
 * Agent-only acceptance audit helpers.
 * Invoke from Merge Worker / Delivery Agent SKILL — not from dispatch lib or workflow bash.
 */

const CLOSES_PATTERN = /(?:^|\n)\s*(?:Closes|Fixes)\s+#\d+/im;
const FOLLOW_UP_PATTERN = /(?:follow-up|Follow-up):\s*#(\d+)/gi;
const INCOMPLETE_MARKERS = /未カバー|手動未実施/;
const UNCHECKED_BOX = /-\s*\[\s*\]/;
const CHECKED_BOX = /-\s*\[x\]/i;

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
  return [...(issueBody ?? '').matchAll(/-\s*\[\s*\]/g)].length;
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
  const incompleteLines = lines.filter(completionLineIsIncomplete);
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
    lines.length > 0 && lines.every(completionLineIsSatisfied);
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
