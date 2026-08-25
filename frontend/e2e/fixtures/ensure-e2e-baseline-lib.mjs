import { countUserOwnedFarms, findBaselineIdInList, firstIdFromList } from '../shared/baseline-ids-lib.mjs';

export const USER_OWNED_FARM_LIMIT = 4;

/**
 * ユーザー農場が上限に達しているときは baseline farm の POST をスキップする。
 * @param {import('../shared/baseline-ids-lib.mjs').JsonRecord[]} rows
 */
export function shouldSkipFarmBaselinePost(rows) {
  return countUserOwnedFarms(rows) >= USER_OWNED_FARM_LIMIT;
}

/**
 * 農場 baseline id を一覧から解決する（prefix 優先 → ユーザー所有先頭 → 一覧先頭）。
 * @param {import('../shared/baseline-ids-lib.mjs').JsonRecord[]} rows
 */
export function resolveFarmBaselineIdFromList(rows) {
  const baseline = findBaselineIdInList(rows, 'farms');
  if (baseline != null) {
    return baseline;
  }
  for (const row of rows) {
    if (row['is_reference'] === false && row['id'] != null) {
      return Number(row['id']);
    }
  }
  return firstIdFromList(rows);
}
