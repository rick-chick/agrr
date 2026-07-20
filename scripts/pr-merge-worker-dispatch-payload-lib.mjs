import { buildDeliveryPrPayloadFromPr } from './delivery-dispatch-lib.mjs';

/**
 * Build webhook payload for Delivery Agent PR dispatch (conflict / sync path).
 *
 * @param {object} params
 * @param {string} params.repository
 * @param {object} params.pr
 * @returns {object}
 */
export function buildConflictDispatchPayload({ repository, pr }) {
  return buildDeliveryPrPayloadFromPr(pr, repository);
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

/**
 * Build webhook payload for Delivery Agent PR review (blocking-label / obsolete path).
 *
 * @param {object} params
 * @param {string} params.repository
 * @param {object} params.pr
 * @returns {object}
 */
export function buildPrReviewDispatchPayload({ repository, pr }) {
  return buildConflictDispatchPayload({ repository, pr });
}
