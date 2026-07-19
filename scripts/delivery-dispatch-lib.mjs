/**
 * Delivery Agent webhook payloads (no action field).
 * Gates and reconcile selection remain in issue-worker-dispatch-lib / pr-merge-worker-retry-dispatch-lib.
 */

/**
 * @param {{
 *   repository: string;
 *   issueNumber: number;
 *   issueTitle?: string;
 *   issueUrl?: string;
 *   labels?: string;
 *   issueBody?: string;
 *   retryReason?: string;
 * }} input
 * @returns {Record<string, unknown>}
 */
export function buildDeliveryIssuePayload({
  repository,
  issueNumber,
  issueTitle,
  issueUrl,
  labels,
  issueBody,
  retryReason,
}) {
  const payload = {
    repository,
    issue_number: issueNumber,
  };
  if (issueTitle !== undefined) {
    payload.issue_title = issueTitle;
  }
  if (issueUrl !== undefined) {
    payload.issue_url = issueUrl;
  }
  if (labels !== undefined) {
    payload.labels = labels;
  }
  if (issueBody !== undefined) {
    payload.issue_body = issueBody;
  }
  if (retryReason) {
    payload.retry_reason = retryReason;
  }
  return payload;
}

/**
 * @param {string | null | undefined} body
 * @returns {number | null}
 */
export function resolveIssueNumberFromPrBody(body) {
  if (!body) {
    return null;
  }
  const match = body.match(/\b(?:closes|fixes)\s+#(\d+)/i);
  if (!match) {
    return null;
  }
  const number = Number(match[1]);
  return Number.isInteger(number) && number > 0 ? number : null;
}

/**
 * @param {{
 *   repository: string;
 *   prNumber: number;
 *   issueNumber?: number | null;
 * }} input
 * @returns {Record<string, unknown>}
 */
export function buildDeliveryPrPayload({
  repository,
  prNumber,
  issueNumber,
}) {
  const payload = {
    repository,
    pr_number: prNumber,
  };
  if (issueNumber != null && issueNumber > 0) {
    payload.issue_number = issueNumber;
  }
  return payload;
}

/**
 * @param {string} logText
 * @returns {number | null}
 */
export function parseDispatchedIssueNumberFromLog(logText) {
  const patterns = [
    /Dispatched Delivery Agent.*#(\d+)/g,
    /Dispatched Issue Worker retry for #(\d+)/g,
  ];
  let last = null;
  for (const pattern of patterns) {
    for (const match of logText.matchAll(pattern)) {
      last = match;
    }
  }
  if (!last) {
    return null;
  }
  const number = Number(last[1]);
  return Number.isInteger(number) && number > 0 ? number : null;
}

/**
 * @param {object} pr
 * @param {string} repository
 * @param {string} [retryReason]
 * @returns {Record<string, unknown>}
 */
export function buildDeliveryPrPayloadFromPr(pr, repository) {
  return buildDeliveryPrPayload({
    repository,
    prNumber: pr.number,
    issueNumber: resolveIssueNumberFromPrBody(pr.body),
  });
}
