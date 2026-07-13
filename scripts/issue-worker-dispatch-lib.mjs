const BOT_AUTHORS = new Set(['dependabot[bot]', 'renovate[bot]', 'github-actions[bot]']);

const OPENED_TERMINAL_LABELS = [
  'agent-in-progress',
  'agent-closed',
  'wontfix',
  'invalid',
  'duplicate',
];

const RETRY_BLOCK_LABELS = ['agent-in-progress', 'agent-skipped', 'agent-blocked'];

/**
 * @param {string} labelsCsv
 * @param {string} name
 * @returns {boolean}
 */
export function hasLabel(labelsCsv, name) {
  return labelsCsv
    .split(',')
    .map((label) => label.trim())
    .filter(Boolean)
    .includes(name);
}

/**
 * @param {{
 *   eventAction: string;
 *   labelName: string;
 *   issueAuthor: string;
 *   issueLabels: string;
 * }} input
 * @returns {{ skip: true; skipReason: string } | { skip: false; action: string }}
 */
export function resolveDispatchAction({ eventAction, labelName, issueAuthor, issueLabels }) {
  if (eventAction === 'labeled') {
    if (labelName === 'agent-close') {
      return { skip: false, action: 'close_with_reason' };
    }
    if (labelName === 'agent-ready') {
      return { skip: false, action: 'implement' };
    }
    return {
      skip: true,
      skipReason: 'labeled event is not agent-ready or agent-close',
    };
  }

  if (eventAction === 'opened') {
    if (BOT_AUTHORS.has(issueAuthor)) {
      return { skip: true, skipReason: 'bot-authored issue' };
    }
    if (hasLabel(issueLabels, 'agent-close')) {
      return { skip: false, action: 'close_with_reason' };
    }
    if (hasLabel(issueLabels, 'agent-ready')) {
      return { skip: false, action: 'implement' };
    }
    for (const label of OPENED_TERMINAL_LABELS) {
      if (hasLabel(issueLabels, label)) {
        return {
          skip: true,
          skipReason: 'issue already has a terminal or in-progress label',
        };
      }
    }
    return { skip: false, action: 'triage' };
  }

  return {
    skip: true,
    skipReason: `unsupported issue event action: ${eventAction}`,
  };
}

/**
 * @param {{
 *   issueLabels: string;
 *   hasOpenFixPr: boolean;
 * }} input
 * @returns {{ eligible: true; action: string } | { eligible: false; reason: string }}
 */
export function isRetryCandidate({ issueLabels, hasOpenFixPr }) {
  if (!hasLabel(issueLabels, 'agent-ready')) {
    return { eligible: false, reason: 'no agent-ready' };
  }
  if (hasLabel(issueLabels, 'agent-close')) {
    return { eligible: false, reason: 'agent-close present' };
  }
  for (const label of RETRY_BLOCK_LABELS) {
    if (hasLabel(issueLabels, label)) {
      return { eligible: false, reason: `has ${label}` };
    }
  }
  if (hasOpenFixPr) {
    return { eligible: false, reason: 'open fix pr exists' };
  }
  return { eligible: true, action: 'implement' };
}

/**
 * @param {Array<{ number: number; labels: string[] }>} issues
 * @param {(issueNumber: number) => boolean} hasOpenFixPrFor
 * @returns {{ issue: { number: number; labels: string[] }; action: string } | null}
 */
export function selectRetryCandidate(issues, hasOpenFixPrFor) {
  const sorted = [...issues].sort((a, b) => a.number - b.number);
  for (const issue of sorted) {
    const labels = issue.labels.join(',');
    const result = isRetryCandidate({
      issueLabels: labels,
      hasOpenFixPr: hasOpenFixPrFor(issue.number),
    });
    if (result.eligible) {
      return { issue, action: result.action };
    }
  }
  return null;
}

/**
 * @param {{
 *   repository: string;
 *   issueNumber: number;
 *   issueTitle: string;
 *   issueUrl: string;
 *   action: string;
 *   labels: string;
 *   issueBody: string;
 *   retryReason?: string;
 * }} input
 * @returns {Record<string, unknown>}
 */
export function buildWebhookPayload({
  repository,
  issueNumber,
  issueTitle,
  issueUrl,
  action,
  labels,
  issueBody,
  retryReason,
}) {
  const payload = {
    repository,
    issue_number: issueNumber,
    issue_title: issueTitle,
    issue_url: issueUrl,
    action,
    labels,
    issue_body: issueBody,
  };
  if (retryReason) {
    payload.retry_reason = retryReason;
  }
  return payload;
}
