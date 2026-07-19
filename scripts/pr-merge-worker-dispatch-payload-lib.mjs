import { buildDeliveryPrPayload, resolveIssueNumberFromPrBody } from './delivery-dispatch-lib.mjs';

/**
 * Build webhook payload for Delivery Agent PR dispatch (conflict / sync path).
 *
 * @param {object} params
 * @param {string} params.repository
 * @param {object} params.pr
 * @returns {object}
 */
export function buildConflictDispatchPayload({ repository, pr }) {
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
  });
}

/**
 * Build webhook payload for Delivery Agent PR dispatch (CI fix path).
 *
 * @param {object} params
 * @param {string} params.repository
 * @param {object} params.pr
 * @returns {object}
 */
export function buildCiFixDispatchPayload({ repository, pr }) {
  return buildConflictDispatchPayload({ repository, pr });
}
