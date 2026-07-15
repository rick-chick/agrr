import {
  BLOCKING_MERGE_LABELS,
  areRequiredChecksGreen,
  isEligibleAgentPr,
} from './pr-agent-prep-lib.mjs';

/** Fresh in-progress runs may still be active. */
export const IN_PROGRESS_STALE_MS = 90 * 60 * 1000;

/** Avoid racing a just-dispatched primary merge worker. */
export const READY_QUIET_MS = 30 * 60 * 1000;

/**
 * @param {Array<{ name: string } | string>} labels
 * @returns {string[]}
 */
function labelNames(labels) {
  return labels.map((label) => (typeof label === 'string' ? label : label.name));
}

/**
 * @param {number} updatedAtMs
 * @param {number} nowMs
 * @param {number} [thresholdMs]
 */
export function isInProgressStale({
  updatedAtMs,
  nowMs,
  thresholdMs = IN_PROGRESS_STALE_MS,
}) {
  return nowMs - updatedAtMs >= thresholdMs;
}

/**
 * @param {{
 *   pr: {
 *     number: number;
 *     isDraft: boolean;
 *     baseRefName: string;
 *     headRefName: string;
 *     body?: string | null;
 *     labels: Array<{ name: string } | string>;
 *     headRepository?: { nameWithOwner?: string };
 *     mergeable?: string;
 *     mergeStateStatus?: string;
 *     reviewDecision?: string;
 *     updatedAt: string;
 *   };
 *   checks: Array<{ name: string; state: string }>;
 *   baseOwner: string;
 *   nowMs: number;
 * }} input
 * @returns {{ eligible: true; removeStaleInProgressLabel: boolean } | { eligible: false; reason: string }}
 */
export function isStuckRetryCandidate({ pr, checks, baseOwner, nowMs }) {
  if (pr.isDraft) {
    return { eligible: false, reason: 'draft pr' };
  }

  const labels = labelNames(pr.labels ?? []);
  if (!labels.includes('agent-merge')) {
    return { eligible: false, reason: 'no agent-merge label' };
  }
  if (labels.some((name) => BLOCKING_MERGE_LABELS.includes(name))) {
    return { eligible: false, reason: 'blocking merge label' };
  }

  const headOwner = (pr.headRepository?.nameWithOwner ?? '').split('/')[0] ?? '';
  if (
    !isEligibleAgentPr({
      authorLogin: '',
      baseRefName: pr.baseRefName,
      headRefName: pr.headRefName,
      body: pr.body,
      labels,
      headOwner,
      baseOwner,
    })
  ) {
    return { eligible: false, reason: 'not eligible agent pr' };
  }

  if (pr.reviewDecision === 'CHANGES_REQUESTED') {
    return { eligible: false, reason: 'changes requested' };
  }

  if (pr.mergeable === 'CONFLICTING' || pr.mergeStateStatus === 'DIRTY') {
    return { eligible: false, reason: 'needs conflict dispatch' };
  }
  if (pr.mergeStateStatus === 'BEHIND') {
    return { eligible: false, reason: 'needs master sync' };
  }
  if (pr.mergeable !== 'MERGEABLE') {
    return { eligible: false, reason: 'not mergeable' };
  }

  if (!areRequiredChecksGreen(checks)) {
    return { eligible: false, reason: 'required ci not green' };
  }

  const updatedAtMs = Date.parse(pr.updatedAt);
  const hasInProgress = labels.includes('agent-merge-in-progress');

  if (hasInProgress) {
    if (!isInProgressStale({ updatedAtMs, nowMs })) {
      return { eligible: false, reason: 'agent-merge-in-progress is fresh' };
    }
    return { eligible: true, removeStaleInProgressLabel: true };
  }

  if (nowMs - updatedAtMs < READY_QUIET_MS) {
    return { eligible: false, reason: 'ready quiet period' };
  }

  return { eligible: true, removeStaleInProgressLabel: false };
}

/**
 * @param {Array<{
 *   number: number;
 *   isDraft: boolean;
 *   baseRefName: string;
 *   headRefName: string;
 *   body?: string | null;
 *   labels: Array<{ name: string } | string>;
 *   headRepository?: { nameWithOwner?: string };
 *   mergeable?: string;
 *   mergeStateStatus?: string;
 *   reviewDecision?: string;
 *   updatedAt: string;
 * }>} prs
 * @param {Record<number, Array<{ name: string; state: string }>>} checksByPrNumber
 * @param {string} baseOwner
 * @param {number} [nowMs]
 * @returns {{ pr: object; removeStaleInProgressLabel: boolean } | null}
 */
export function selectStuckRetryCandidate(
  prs,
  checksByPrNumber,
  baseOwner,
  nowMs = Date.now(),
) {
  const sorted = [...prs].sort((a, b) => a.number - b.number);
  for (const pr of sorted) {
    const checks = checksByPrNumber[pr.number] ?? [];
    const result = isStuckRetryCandidate({ pr, checks, baseOwner, nowMs });
    if (result.eligible) {
      return {
        pr,
        removeStaleInProgressLabel: result.removeStaleInProgressLabel,
      };
    }
  }
  return null;
}

/**
 * @param {{
 *   repository: string;
 *   pr: {
 *     number: number;
 *     title: string;
 *     url: string;
 *     headRefName: string;
 *     headRefOid: string;
 *     author?: { login?: string };
 *     mergeable?: string;
 *     mergeStateStatus?: string;
 *   };
 *   retryReason?: string;
 * }} input
 */
export function buildRetryDispatchPayload({ repository, pr, retryReason }) {
  const payload = {
    repository,
    pr_number: pr.number,
    pr_title: pr.title,
    pr_url: pr.url,
    action: 'stuck_retry',
    head_ref: pr.headRefName,
    head_sha: pr.headRefOid,
    author: pr.author?.login ?? '',
    mergeable_state: pr.mergeable ?? '',
    merge_state_status: pr.mergeStateStatus ?? '',
  };
  if (retryReason) {
    payload.retry_reason = retryReason;
  }
  return payload;
}
