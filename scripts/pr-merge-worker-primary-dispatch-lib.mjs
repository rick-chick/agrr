import { prMergeWorkerNeedsSync } from './pr-merge-worker-needs-sync.mjs';

/**
 * @param {Array<{ number?: number }> | null | undefined} closingIssuesReferences
 * @returns {number}
 */
export function closingIssueCountFromReferences(closingIssuesReferences) {
  if (!Array.isArray(closingIssuesReferences)) {
    return 0;
  }
  return closingIssuesReferences.filter((ref) => ref?.number != null).length;
}

/**
 * Linked Draft PRs wait for pr-agent-prep. Unlinked Drafts need Delivery Agent.
 *
 * @param {{
 *   isDraft: boolean;
 *   closingIssueCount: number;
 *   needsSync: boolean;
 *   requiredCiState: 'incomplete' | 'failed' | 'green';
 * }} input
 */
export function isLinkedDraftWaitingForPrep(input) {
  if (!input.isDraft || input.needsSync || input.requiredCiState === 'failed') {
    return false;
  }
  return input.closingIssueCount > 0;
}

/**
 * @param {string | Array<string | { name?: string }>} labels
 * @returns {string[]}
 */
export function parseCommaSeparatedLabels(labels) {
  if (Array.isArray(labels)) {
    return labels.map((label) =>
      typeof label === 'string' ? label : (label?.name ?? ''),
    ).filter(Boolean);
  }
  if (!labels) {
    return [];
  }
  return labels
    .split(',')
    .map((name) => name.trim())
    .filter(Boolean);
}

/**
 * Primary PR Merge Worker dispatch gates (pure). Workflow bash must not duplicate this logic.
 *
 * @param {{
 *   labels: string | Array<string | { name?: string }>;
 *   eventAction: string;
 *   labelName?: string;
 *   isDraft: boolean;
 *   reviewDecision?: string | null;
 *   baseRefName: string;
 *   headOwner: string;
 *   baseOwner: string;
 *   headOid: string;
 *   eventHeadSha: string;
 *   mergeable?: string | null;
 *   mergeStateStatus?: string | null;
 *   requiredCiState: 'incomplete' | 'failed' | 'green';
 *   closingIssueCount?: number;
 * }} input
 * @returns {{ eligible: true } | { eligible: false; reason: string }}
 */
export function classifyPrimaryPrMergeDispatch(input) {
  const labelNames = parseCommaSeparatedLabels(input.labels);

  if (labelNames.includes('agent-merge-in-progress')) {
    return { eligible: false, reason: 'agent-merge-in-progress' };
  }

  if (input.eventAction === 'labeled' && input.labelName !== 'agent-merge') {
    return { eligible: false, reason: 'labeled not agent-merge' };
  }

  const needsSync = prMergeWorkerNeedsSync({
    mergeable: input.mergeable,
    mergeStateStatus: input.mergeStateStatus,
  });

  if (!needsSync && input.eventAction === 'synchronize') {
    return { eligible: false, reason: 'synchronize without sync need' };
  } else if (input.requiredCiState === 'failed') {
    // Failed required CI is enough to re-run the Delivery Agent; the Agent observes the PR.
  } else if (
    isLinkedDraftWaitingForPrep({
      isDraft: input.isDraft,
      closingIssueCount: input.closingIssueCount ?? 0,
      needsSync,
      requiredCiState: input.requiredCiState,
    })
  ) {
    return { eligible: false, reason: 'linked draft waiting for prep' };
  } else if (
    input.requiredCiState === 'incomplete' &&
    input.eventAction === 'ci_completed'
  ) {
    return { eligible: false, reason: 'required ci incomplete' };
  }

  if (input.headOwner !== input.baseOwner) {
    return { eligible: false, reason: 'fork pr' };
  }

  if (input.reviewDecision === 'CHANGES_REQUESTED') {
    return { eligible: false, reason: 'changes requested' };
  }

  if (input.baseRefName !== 'master') {
    return { eligible: false, reason: 'not master base' };
  }

  if (!needsSync && input.headOid !== input.eventHeadSha) {
    return { eligible: false, reason: 'stale head sha' };
  }

  return { eligible: true };
}
