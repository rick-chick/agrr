import { buildDeliveryPrPayloadFromPr } from './delivery-dispatch-lib.mjs';

/**
 * Build webhook payload for Delivery Agent PR dispatch.
 *
 * @param {object} params
 * @param {string} params.repository
 * @param {object} params.pr
 * @returns {object}
 */
export function buildPrMergeWorkerDispatchPayload({ repository, pr }) {
  return buildDeliveryPrPayloadFromPr(pr, repository);
}
