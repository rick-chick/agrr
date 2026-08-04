/**
 * Agent-only acceptance audit helpers — GitHub API structural fields only.
 * Invoke from Merge Worker / Delivery Agent SKILL — not from dispatch lib or workflow bash.
 *
 * Does NOT parse issue/PR body text. Agent reads body via `gh` for semantic judgment
 * (本番確認の無視、Closes 禁止、未達条件の有無). This lib only gates on
 * `acceptance-follow-up` issue state supplied by the Agent after `gh` observation.
 */

/**
 * @param {Array<{ number: number; state: string; labels?: string[] }>} followUpIssues
 */
function acceptanceFollowUpIssues(followUpIssues) {
  return (followUpIssues ?? []).filter((issue) =>
    (issue.labels ?? []).includes('acceptance-follow-up'),
  );
}

/**
 * @param {{
 *   followUpIssues?: Array<{ number: number; state: string; labels?: string[] }>;
 * }} input
 * @returns {{
 *   mergeAllowed: boolean;
 *   closeParentAllowed: boolean;
 *   reasons: string[];
 * }}
 */
export function auditLinkedPrAcceptance(input) {
  const followUps = acceptanceFollowUpIssues(input.followUpIssues);
  const openFollowUps = followUps.filter((issue) => issue.state === 'OPEN');

  if (openFollowUps.length > 0) {
    return {
      mergeAllowed: true,
      closeParentAllowed: false,
      reasons: [
        `Open acceptance-follow-up: ${openFollowUps.map((i) => `#${i.number}`).join(', ')}`,
      ],
    };
  }

  return {
    mergeAllowed: true,
    closeParentAllowed: true,
    reasons: ['No open acceptance-follow-up issues'],
  };
}

/**
 * @param {{
 *   followUpIssues: Array<{ number: number; state: string; labels?: string[] }>;
 * }} input
 * @returns {{ closeAllowed: boolean; reasons: string[] }}
 */
export function auditParentIssueCloseEligibility(input) {
  const followUps = acceptanceFollowUpIssues(input.followUpIssues);
  const openFollowUps = followUps.filter((issue) => issue.state === 'OPEN');

  if (openFollowUps.length > 0) {
    return {
      closeAllowed: false,
      reasons: [
        `Open acceptance-follow-up: ${openFollowUps.map((i) => `#${i.number}`).join(', ')}`,
      ],
    };
  }

  if (followUps.length > 0) {
    return {
      closeAllowed: true,
      reasons: ['All acceptance-follow-up issues closed'],
    };
  }

  return {
    closeAllowed: true,
    reasons: [
      'No acceptance-follow-up tracking; close at Agent discretion after gh body observation',
    ],
  };
}
