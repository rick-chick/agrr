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
 *   prTitle?: string;
 *   prUrl?: string;
 *   headRef?: string;
 *   headSha?: string;
 *   author?: string;
 *   mergeableState?: string;
 *   mergeStateStatus?: string;
 *   retryReason?: string;
 * }} input
 * @returns {Record<string, unknown>}
 */
export function buildDeliveryPrPayload({
  repository,
  prNumber,
  issueNumber,
  prTitle,
  prUrl,
  headRef,
  headSha,
  author,
  mergeableState,
  mergeStateStatus,
  retryReason,
}) {
  const payload = {
    repository,
    pr_number: prNumber,
  };
  if (issueNumber != null && issueNumber > 0) {
    payload.issue_number = issueNumber;
  }
  if (prTitle !== undefined) {
    payload.pr_title = prTitle;
  }
  if (prUrl !== undefined) {
    payload.pr_url = prUrl;
  }
  if (headRef !== undefined) {
    payload.head_ref = headRef;
  }
  if (headSha !== undefined) {
    payload.head_sha = headSha;
  }
  if (author !== undefined) {
    payload.author = author;
  }
  if (mergeableState !== undefined) {
    payload.mergeable_state = mergeableState;
  }
  if (mergeStateStatus !== undefined) {
    payload.merge_state_status = mergeStateStatus;
  }
  if (retryReason) {
    payload.retry_reason = retryReason;
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
export function buildDeliveryPrPayloadFromPr(pr, repository, retryReason) {
  return buildDeliveryPrPayload({
    repository,
    prNumber: pr.number,
    issueNumber: resolveIssueNumberFromPrBody(pr.body),
    prTitle: pr.title,
    prUrl: pr.url,
    headRef: pr.headRefName,
    headSha: pr.headRefOid,
    author: pr.author?.login ?? '',
    mergeableState: pr.mergeable ?? '',
    mergeStateStatus: pr.mergeStateStatus ?? '',
    retryReason,
  });
}
