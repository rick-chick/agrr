/** @typedef {import('../shared/baseline-ids-lib.mjs').MasterSegment} MasterSegment */

import { countUserOwnedFarms } from '../shared/baseline-ids-lib.mjs';

export const USER_FARM_LIMIT = 4;

/**
 * @param {number} ownedFarmCount
 * @param {number} [limit]
 */
export function shouldSkipFarmBaselineCreate(ownedFarmCount, limit = USER_FARM_LIMIT) {
  return ownedFarmCount >= limit;
}

/**
 * @param {import('../shared/baseline-ids-lib.mjs').JsonRecord[]} rows
 * @param {MasterSegment} segment
 * @param {{
 *   findBaselineIdInList: (rows: import('../shared/baseline-ids-lib.mjs').JsonRecord[], segment: MasterSegment) => number | null;
 *   firstIdFromList: (rows: import('../shared/baseline-ids-lib.mjs').JsonRecord[]) => number | null;
 * }} pickers
 */
export function pickFarmIdWhenBaselineCreateSkipped(rows, segment, pickers) {
  return pickers.findBaselineIdInList(rows, segment) ?? pickers.firstIdFromList(rows);
}

/**
 * @param {import('../shared/baseline-ids-lib.mjs').JsonRecord[]} rows
 * @param {MasterSegment} segment
 * @param {{
 *   findBaselineIdInList: (rows: import('../shared/baseline-ids-lib.mjs').JsonRecord[], segment: MasterSegment) => number | null;
 *   firstIdFromList: (rows: import('../shared/baseline-ids-lib.mjs').JsonRecord[]) => number | null;
 * }} pickers
 * @param {number} [limit]
 */
export function resolveFarmIdWhenUserAtLimit(rows, segment, pickers, limit = USER_FARM_LIMIT) {
  const ownedCount = countUserOwnedFarms(rows);
  if (!shouldSkipFarmBaselineCreate(ownedCount, limit)) {
    return null;
  }
  return pickFarmIdWhenBaselineCreateSkipped(rows, segment, pickers);
}
