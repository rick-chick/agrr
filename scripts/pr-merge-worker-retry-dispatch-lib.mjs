import {
  DISPATCH_SKIP_LABELS,
  areRequiredChecksComplete,
  areRequiredChecksGreen,
} from './pr-agent-prep-lib.mjs';
import {
  buildDeliveryPrPayloadFromPr,
} from './delivery-dispatch-lib.mjs';
import { prMergeWorkerNeedsSync } from './pr-merge-worker-needs-sync.mjs';

/** Fresh in-progress runs may still be active. */
export const IN_PROGRESS_STALE_MS = 90 * 60 * 1000;

/** Avoid racing a just-dispatched primary merge worker. */
export const READY_QUIET_MS = 30 * 60 * 1000;

/** Lower value = higher reconcile priority. */
export const RECONCILE_ACTION_PRIORITY = {
  conflict: 0,
  ci_fix: 1,
  pr_review: 2,
  stuck_retry: 3,
};

/**
 * @param {Array<{ name: string } | string>} labels
 * @returns {string[]}
 */
function labelNames(labels) {
  return labels.map((label) => (typeof label === 'string' ? label : label.name));
}

/**
 * Opt-out gates only (universal rescue). No agent-merge / branch-prefix opt-in.
 *
 * @param {{
 *   baseRefName: string;
 *   headRepository?: { nameWithOwner?: string };
 *   labels: string[];
 * }} pr
 * @param {string} baseOwner
 */
function isUniversalMergeWorkerTarget(pr, baseOwner) {
  if (pr.baseRefName !== 'master') {
    return false;
  }
  const headOwner = (pr.headRepository?.nameWithOwner ?? '').split('/')[0] ?? '';
  if (headOwner !== baseOwner) {
    return false;
  }
  if (pr.labels.some((name) => DISPATCH_SKIP_LABELS.includes(name))) {
    return false;
  }
  return true;
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
 *   baseOwner: string;
 * }} input
 * @returns {{ eligible: true } | { eligible: false; reason: string }}
 */
function classifyBaseEligibility({ pr, baseOwner }) {
  const labels = labelNames(pr.labels ?? []);
  const needsSync = prMergeWorkerNeedsSync(pr);

  if (pr.isDraft && !needsSync) {
    return { eligible: false, reason: 'draft pr' };
  }

  if (!isUniversalMergeWorkerTarget({ ...pr, labels }, baseOwner)) {
    if (pr.baseRefName !== 'master') {
      return { eligible: false, reason: 'not eligible agent pr' };
    }
    const headOwner = (pr.headRepository?.nameWithOwner ?? '').split('/')[0] ?? '';
    if (headOwner !== baseOwner) {
      return { eligible: false, reason: 'not eligible agent pr' };
    }
    if (labels.some((name) => DISPATCH_SKIP_LABELS.includes(name))) {
      return { eligible: false, reason: 'blocking merge label' };
    }
    return { eligible: false, reason: 'not eligible agent pr' };
  }

  if (pr.reviewDecision === 'CHANGES_REQUESTED') {
    return { eligible: false, reason: 'changes requested' };
  }

  return { eligible: true };
}

/**
 * Required CI failure (no master sync need). Draft or ready; no agent-merge required.
 *
 * @param {{
 *   pr: object;
 *   checks: Array<{ name: string; state: string }>;
 *   baseOwner: string;
 *   nowMs: number;
 *   labels: string[];
 * }} input
 */
function classifyCiFixCandidate({ pr, checks, baseOwner, nowMs, labels }) {
  if (!isUniversalMergeWorkerTarget({ ...pr, labels }, baseOwner)) {
    if (labels.some((name) => DISPATCH_SKIP_LABELS.includes(name))) {
      return { eligible: false, reason: 'blocking merge label' };
    }
    return { eligible: false, reason: 'not eligible agent pr' };
  }

  if (pr.reviewDecision === 'CHANGES_REQUESTED') {
    return { eligible: false, reason: 'changes requested' };
  }

  if (pr.mergeable !== 'MERGEABLE') {
    return { eligible: false, reason: 'not mergeable' };
  }

  if (!areRequiredChecksComplete(checks)) {
    return { eligible: false, reason: 'required ci incomplete' };
  }

  if (areRequiredChecksGreen(checks)) {
    return { eligible: false, reason: 'required ci already green' };
  }

  const hasInProgress = labels.includes('agent-merge-in-progress');
  const updatedAtMs = Date.parse(pr.updatedAt);

  if (hasInProgress && !isInProgressStale({ updatedAtMs, nowMs })) {
    return { eligible: false, reason: 'agent-merge-in-progress is fresh' };
  }

  return {
    eligible: true,
    action: 'ci_fix',
    removeStaleInProgressLabel:
      hasInProgress && isInProgressStale({ updatedAtMs, nowMs }),
  };
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
 * @returns {{
 *   eligible: true;
 *   action: 'conflict' | 'stuck_retry' | 'ci_fix';
 *   removeStaleInProgressLabel: boolean;
 * } | { eligible: false; reason: string }}
 */
export function classifyReconcileCandidate({ pr, checks, baseOwner, nowMs }) {
  const labels = labelNames(pr.labels ?? []);
  const hasInProgress = labels.includes('agent-merge-in-progress');
  const updatedAtMs = Date.parse(pr.updatedAt);

  if (prMergeWorkerNeedsSync(pr)) {
    if (!isUniversalMergeWorkerTarget({ ...pr, labels }, baseOwner)) {
      if (labels.some((name) => DISPATCH_SKIP_LABELS.includes(name))) {
        return { eligible: false, reason: 'blocking merge label' };
      }
      return { eligible: false, reason: 'not eligible agent pr' };
    }
    if (pr.reviewDecision === 'CHANGES_REQUESTED') {
      return { eligible: false, reason: 'changes requested' };
    }
    if (hasInProgress && !isInProgressStale({ updatedAtMs, nowMs })) {
      return { eligible: false, reason: 'agent-merge-in-progress is fresh' };
    }
    return {
      eligible: true,
      action: 'conflict',
      removeStaleInProgressLabel:
        hasInProgress && isInProgressStale({ updatedAtMs, nowMs }),
    };
  }

  const ciFix = classifyCiFixCandidate({
    pr,
    checks,
    baseOwner,
    nowMs,
    labels,
  });
  if (ciFix.eligible) {
    return ciFix;
  }
  // CI green → continue to stuck_retry. Any other ci_fix rejection is final.
  if (ciFix.reason !== 'required ci already green') {
    return ciFix;
  }

  const base = classifyBaseEligibility({ pr, baseOwner });
  if (!base.eligible) {
    return base;
  }

  if (pr.mergeable !== 'MERGEABLE') {
    return { eligible: false, reason: 'not mergeable' };
  }

  if (!areRequiredChecksGreen(checks)) {
    return { eligible: false, reason: 'required ci not green' };
  }

  if (hasInProgress) {
    if (!isInProgressStale({ updatedAtMs, nowMs })) {
      return { eligible: false, reason: 'agent-merge-in-progress is fresh' };
    }
    return {
      eligible: true,
      action: 'stuck_retry',
      removeStaleInProgressLabel: true,
    };
  }

  if (nowMs - updatedAtMs < READY_QUIET_MS) {
    return { eligible: false, reason: 'ready quiet period' };
  }

  return {
    eligible: true,
    action: 'stuck_retry',
    removeStaleInProgressLabel: false,
  };
}

/**
 * Blocking-label PRs need Agent review (obsolete close, label correction, etc.).
 * Structure gates only — no title/body parse.
 *
 * @param {{
 *   pr: {
 *     number: number;
 *     baseRefName: string;
 *     labels: Array<{ name: string } | string>;
 *     headRepository?: { nameWithOwner?: string };
 *     updatedAt: string;
 *   };
 *   baseOwner: string;
 *   nowMs: number;
 * }} input
 * @returns {{
 *   eligible: true;
 *   action: 'pr_review';
 *   removeStaleInProgressLabel: boolean;
 * } | { eligible: false; reason: string }}
 */
export function classifyPrReviewCandidate({ pr, baseOwner, nowMs }) {
  const labels = labelNames(pr.labels ?? []);
  const hasInProgress = labels.includes('agent-merge-in-progress');
  const updatedAtMs = Date.parse(pr.updatedAt);

  if (pr.baseRefName !== 'master') {
    return { eligible: false, reason: 'not master' };
  }

  const headOwner = (pr.headRepository?.nameWithOwner ?? '').split('/')[0] ?? '';
  if (headOwner !== baseOwner) {
    return { eligible: false, reason: 'fork pr' };
  }

  if (!labels.some((name) => DISPATCH_SKIP_LABELS.includes(name))) {
    return { eligible: false, reason: 'no blocking merge label' };
  }

  if (hasInProgress && !isInProgressStale({ updatedAtMs, nowMs })) {
    return { eligible: false, reason: 'agent-merge-in-progress is fresh' };
  }

  if (nowMs - updatedAtMs < READY_QUIET_MS) {
    return { eligible: false, reason: 'ready quiet period' };
  }

  return {
    eligible: true,
    action: 'pr_review',
    removeStaleInProgressLabel:
      hasInProgress && isInProgressStale({ updatedAtMs, nowMs }),
  };
}

/**
 * @param {{
 *   pr: object;
 *   checks: Array<{ name: string; state: string }>;
 *   baseOwner: string;
 *   nowMs: number;
 * }} input
 * @returns {{
 *   eligible: true;
 *   action: 'conflict' | 'stuck_retry' | 'ci_fix' | 'pr_review';
 *   removeStaleInProgressLabel: boolean;
 * } | { eligible: false; reason: string } | null}
 */
export function classifyReconcileDispatchCandidate({ pr, checks, baseOwner, nowMs }) {
  const reconcile = classifyReconcileCandidate({ pr, checks, baseOwner, nowMs });
  if (reconcile.eligible) {
    return reconcile;
  }
  return classifyPrReviewCandidate({ pr, baseOwner, nowMs });
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
 * @returns {{
 *   pr: object;
 *   action: 'conflict' | 'stuck_retry' | 'ci_fix' | 'pr_review';
 *   removeStaleInProgressLabel: boolean;
 * } | null}
 */
export function selectReconcileCandidate(
  prs,
  checksByPrNumber,
  baseOwner,
  nowMs = Date.now(),
) {
  const sorted = [...prs].sort((a, b) => a.number - b.number);
  /** @type {Array<{ pr: object; action: 'conflict' | 'stuck_retry' | 'ci_fix' | 'pr_review'; removeStaleInProgressLabel: boolean }>} */
  const candidates = [];

  for (const pr of sorted) {
    const checks = checksByPrNumber[pr.number] ?? [];
    const result = classifyReconcileDispatchCandidate({
      pr,
      checks,
      baseOwner,
      nowMs,
    });
    if (result?.eligible) {
      candidates.push({
        pr,
        action: result.action,
        removeStaleInProgressLabel: result.removeStaleInProgressLabel,
      });
    }
  }

  if (candidates.length === 0) {
    return null;
  }

  candidates.sort((a, b) => {
    const priorityDelta =
      RECONCILE_ACTION_PRIORITY[a.action] - RECONCILE_ACTION_PRIORITY[b.action];
    if (priorityDelta !== 0) {
      return priorityDelta;
    }
    return a.pr.number - b.pr.number;
  });

  return candidates[0];
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
export function buildRetryDispatchPayload({ repository, pr }) {
  return buildDeliveryPrPayloadFromPr(pr, repository);
}
