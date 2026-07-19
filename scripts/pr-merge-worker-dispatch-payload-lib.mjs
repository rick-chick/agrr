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
