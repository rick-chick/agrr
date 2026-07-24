import {
  areRequiredChecksComplete,
  areRequiredChecksGreen,
} from './pr-agent-prep-lib.mjs';
import {
  buildDeliveryPrPayloadFromPr,
} from './delivery-dispatch-lib.mjs';
import {
  closingIssueCountFromReferences,
  isLinkedDraftWaitingForPrep,
} from './pr-merge-worker-primary-dispatch-lib.mjs';
import { prMergeWorkerNeedsSync } from './pr-merge-worker-needs-sync.mjs';

/** Fresh in-progress runs may still be active. */
export const IN_PROGRESS_STALE_MS = 90 * 60 * 1000;

/** Avoid racing a just-dispatched primary merge worker. */
export const READY_QUIET_MS = 30 * 60 * 1000;

/** Lower value = higher reconcile priority; internal only. */
const RECONCILE_PRIORITY = {
  NEEDS_SYNC: 0,
  REQUIRED_CI_FAILED: 1,
  READY_OR_STALE: 2,
};

/**
 * @param {Array<{ name: string } | string>} labels
 * @returns {string[]}
 */
function labelNames(labels) {
  return labels.map((label) => (typeof label === 'string' ? label : label.name));
}

/**
 * Structural gates only (universal rescue). No agent-merge / branch-prefix opt-in.
 *
 * @param {{
 *   baseRefName: string;
 *   headRepository?: { nameWithOwner?: string };
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

  if (
    isLinkedDraftWaitingForPrep({
      isDraft: pr.isDraft,
      closingIssueCount: closingIssueCountFromReferences(pr.closingIssuesReferences),
      needsSync,
      requiredCiState: 'green',
    })
  ) {
    return { eligible: false, reason: 'linked draft waiting for prep' };
  }

  if (!isUniversalMergeWorkerTarget(pr, baseOwner)) {
    if (pr.baseRefName !== 'master') {
      return { eligible: false, reason: 'not eligible agent pr' };
    }
    const headOwner = (pr.headRepository?.nameWithOwner ?? '').split('/')[0] ?? '';
    if (headOwner !== baseOwner) {
      return { eligible: false, reason: 'not eligible agent pr' };
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
function classifyRequiredCiFailureCandidate({ pr, checks, baseOwner, nowMs, labels }) {
  if (!isUniversalMergeWorkerTarget(pr, baseOwner)) {
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
 *   result: {{ eligible: true; removeStaleInProgressLabel: boolean } | { eligible: false; reason: string }};
 *   priority?: number;
 * }}
 */
function classifyReconcileCandidateWithPriority({ pr, checks, baseOwner, nowMs }) {
  const labels = labelNames(pr.labels ?? []);
  const hasInProgress = labels.includes('agent-merge-in-progress');
  const updatedAtMs = Date.parse(pr.updatedAt);

  if (prMergeWorkerNeedsSync(pr)) {
    if (!isUniversalMergeWorkerTarget(pr, baseOwner)) {
      return { result: { eligible: false, reason: 'not eligible agent pr' } };
    }
    if (pr.reviewDecision === 'CHANGES_REQUESTED') {
      return { result: { eligible: false, reason: 'changes requested' } };
    }
    if (hasInProgress && !isInProgressStale({ updatedAtMs, nowMs })) {
      return {
        result: { eligible: false, reason: 'agent-merge-in-progress is fresh' },
      };
    }
    return {
      result: {
        eligible: true,
        removeStaleInProgressLabel:
          hasInProgress && isInProgressStale({ updatedAtMs, nowMs }),
      },
      priority: RECONCILE_PRIORITY.NEEDS_SYNC,
    };
  }

  const requiredCiFailure = classifyRequiredCiFailureCandidate({
    pr,
    checks,
    baseOwner,
    nowMs,
    labels,
  });
  if (requiredCiFailure.eligible) {
    return {
      result: requiredCiFailure,
      priority: RECONCILE_PRIORITY.REQUIRED_CI_FAILED,
    };
  }
  // CI green can continue to generic quiet/stale reconcile. Other CI rejection is final.
  if (requiredCiFailure.reason !== 'required ci already green') {
    return { result: requiredCiFailure };
  }

  const base = classifyBaseEligibility({ pr, baseOwner });
  if (!base.eligible) {
    return { result: base };
  }

  if (pr.mergeable !== 'MERGEABLE') {
    return { result: { eligible: false, reason: 'not mergeable' } };
  }

  if (!areRequiredChecksGreen(checks)) {
    return { result: { eligible: false, reason: 'required ci not green' } };
  }

  if (hasInProgress) {
    if (!isInProgressStale({ updatedAtMs, nowMs })) {
      return {
        result: { eligible: false, reason: 'agent-merge-in-progress is fresh' },
      };
    }
    return {
      result: {
        eligible: true,
        removeStaleInProgressLabel: true,
      },
      priority: RECONCILE_PRIORITY.READY_OR_STALE,
    };
  }

  if (nowMs - updatedAtMs < READY_QUIET_MS) {
    return { result: { eligible: false, reason: 'ready quiet period' } };
  }

  return {
    result: {
      eligible: true,
      removeStaleInProgressLabel: false,
    },
    priority: RECONCILE_PRIORITY.READY_OR_STALE,
  };
}

export function classifyReconcileCandidate({ pr, checks, baseOwner, nowMs }) {
  return classifyReconcileCandidateWithPriority({
    pr,
    checks,
    baseOwner,
    nowMs,
  }).result;
}

/**
 * @param {{
 *   pr: object;
 *   checks: Array<{ name: string; state: string }>;
 *   baseOwner: string;
 *   nowMs: number;
 * }} input
 * @returns {{ eligible: true; removeStaleInProgressLabel: boolean } | { eligible: false; reason: string } | null}
 */
export function classifyReconcileDispatchCandidate({ pr, checks, baseOwner, nowMs }) {
  return classifyReconcileCandidate({ pr, checks, baseOwner, nowMs });
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
export function selectReconcileCandidate(
  prs,
  checksByPrNumber,
  baseOwner,
  nowMs = Date.now(),
) {
  const sorted = [...prs].sort((a, b) => a.number - b.number);
  /** @type {Array<{ pr: object; priority: number; removeStaleInProgressLabel: boolean }>} */
  const candidates = [];

  for (const pr of sorted) {
    const checks = checksByPrNumber[pr.number] ?? [];
    const classification = classifyReconcileCandidateWithPriority({
      pr,
      checks,
      baseOwner,
      nowMs,
    });
    if (classification.result?.eligible) {
      candidates.push({
        pr,
        priority: classification.priority,
        removeStaleInProgressLabel:
          classification.result.removeStaleInProgressLabel,
      });
    }
  }

  if (candidates.length === 0) {
    return null;
  }

  candidates.sort((a, b) => {
    const priorityDelta = a.priority - b.priority;
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
