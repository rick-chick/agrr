/**
 * Build webhook payload for PR Merge Worker conflict/sync dispatch.
 *
 * @param {object} params
 * @param {string} params.repository
 * @param {object} params.pr
 * @param {number} params.pr.number
 * @param {string} params.pr.title
 * @param {string} params.pr.url
 * @param {string} params.pr.headRefName
 * @param {string} params.pr.headRefOid
 * @param {{ login?: string } | undefined} params.pr.author
 * @param {string} [params.pr.mergeable]
 * @param {string} [params.pr.mergeStateStatus]
 * @returns {object}
 */
export function buildConflictDispatchPayload({ repository, pr }) {
  return {
    repository,
    pr_number: pr.number,
    pr_title: pr.title,
    pr_url: pr.url,
    action: 'conflict',
    head_ref: pr.headRefName,
    head_sha: pr.headRefOid,
    author: pr.author?.login ?? '',
    mergeable_state: pr.mergeable ?? '',
    merge_state_status: pr.mergeStateStatus ?? '',
  };
}

/**
 * Build webhook payload for PR Merge Worker draft CI fix dispatch.
 *
 * @param {object} params
 * @param {string} params.repository
 * @param {object} params.pr
 * @returns {object}
 */
export function buildCiFixDispatchPayload({ repository, pr }) {
  return {
    repository,
    pr_number: pr.number,
    pr_title: pr.title,
    pr_url: pr.url,
    action: 'ci_fix',
    head_ref: pr.headRefName,
    head_sha: pr.headRefOid,
    author: pr.author?.login ?? '',
    mergeable_state: pr.mergeable ?? '',
    merge_state_status: pr.mergeStateStatus ?? '',
  };
}
