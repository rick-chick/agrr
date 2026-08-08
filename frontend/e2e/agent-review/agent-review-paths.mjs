import { join } from 'node:path';

/** Ephemeral agent-review artifacts live under frontend/tmp (gitignored via /tmp). */
export const AGENT_REVIEW_TMP_DIR = 'tmp/agent-review';

export const BUNDLE_FILENAME = 'agent-review-bundle.json';
export const VISUAL_REVIEW_FILENAME = 'visual-review.json';
export const COGNITIVE_REVIEW_FILENAME = 'cognitive-guidance-review.json';
export const UX_FINDINGS_DRAFT_FILENAME = 'ux-findings-draft.json';
export const UX_ISSUE_DRAFTS_FILENAME = 'ux-issue-drafts.md';

/**
 * @param {string} frontendRoot
 */
export function agentReviewTmpDir(frontendRoot) {
  return join(frontendRoot, AGENT_REVIEW_TMP_DIR);
}

/**
 * @param {string} frontendRoot
 */
export function bundlePath(frontendRoot) {
  return join(agentReviewTmpDir(frontendRoot), BUNDLE_FILENAME);
}

/**
 * @param {string} frontendRoot
 */
export function visualReviewPath(frontendRoot) {
  return join(agentReviewTmpDir(frontendRoot), VISUAL_REVIEW_FILENAME);
}

/**
 * @param {string} frontendRoot
 */
export function cognitiveReviewPath(frontendRoot) {
  return join(agentReviewTmpDir(frontendRoot), COGNITIVE_REVIEW_FILENAME);
}

/**
 * @param {string} frontendRoot
 */
export function uxFindingsDraftPath(frontendRoot) {
  return join(agentReviewTmpDir(frontendRoot), UX_FINDINGS_DRAFT_FILENAME);
}

/**
 * @param {string} frontendRoot
 */
export function uxIssueDraftsPath(frontendRoot) {
  return join(agentReviewTmpDir(frontendRoot), UX_ISSUE_DRAFTS_FILENAME);
}
