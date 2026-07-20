import { hasBlockingMergeLabel } from './pr-agent-prep-lib.mjs';
import { prMergeWorkerNeedsSync } from './pr-merge-worker-needs-sync.mjs';

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
 *   title?: string;
 * }} input
 * @returns {
 *   { eligible: true; dispatchKind: 'conflict' | 'ci_fix' | 'default' }
 *   | { eligible: false; reason: string }
 * }
 */
export function classifyPrimaryPrMergeDispatch(input) {
  const labelNames = parseCommaSeparatedLabels(input.labels);

  if (hasBlockingMergeLabel(labelNames)) {
    return { eligible: false, reason: 'blocking merge label' };
  }

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

  let dispatchKind = 'default';

  if (needsSync) {
    dispatchKind = 'conflict';
  } else if (input.eventAction === 'synchronize') {
    return { eligible: false, reason: 'synchronize without conflict' };
  } else if (input.requiredCiState === 'failed') {
    dispatchKind = 'ci_fix';
  } else if (input.isDraft) {
    return { eligible: false, reason: 'draft without conflict or ci failure' };
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

  if (dispatchKind !== 'conflict' && input.headOid !== input.eventHeadSha) {
    return { eligible: false, reason: 'stale head sha' };
  }

  return { eligible: true, dispatchKind };
}
