import {
  hasBlockingMergeLabel,
  shouldReceiveAgentMergeLabel,
} from './pr-agent-prep-lib.mjs';

/**
 * @param {Array<string | { name?: string }>} labels
 * @returns {string[]}
 */
function labelNames(labels) {
  return labels.map((label) => (typeof label === 'string' ? label : label.name));
}

/**
 * Decide whether reconcile prep should opt an open PR out of auto-merge
 * because it has no linked issue (`closingIssuesReferences` empty).
 *
 * @param {{
 *   labels: Array<string | { name?: string }>;
 *   closingIssuesReferences?: Array<unknown> | null;
 * }} pr
 * @returns {{
 *   optOut: true;
 *   removeAgentMerge: boolean;
 * } | { optOut: false }}
 */
export function resolveUnlinkedPrOptOut(pr) {
  const labels = labelNames(pr.labels ?? []);
  if (hasBlockingMergeLabel(labels)) {
    return { optOut: false };
  }
  const closingIssues = pr.closingIssuesReferences ?? [];
  if (shouldReceiveAgentMergeLabel({ closingIssueCount: closingIssues.length })) {
    return { optOut: false };
  }
  return {
    optOut: true,
    removeAgentMerge: labels.includes('agent-merge'),
  };
}
