/** GET /api/v1/masters/:segment の URL セグメント（resolve-capture-urls と共有） */
export const MASTER_SEGMENTS = [
  'agricultural_tasks',
  'crops',
  'farms',
  'fertilizes',
  'interaction_rules',
  'pesticides',
  'pests',
];

export const E2E_BASELINE_PREFIX = 'E2E Baseline';

export function parseMasterList(data) {
  return Array.isArray(data) ? data : [];
}

export function baselineLabel(row, segment) {
  if (segment === 'interaction_rules') {
    const source = row['source_group'];
    return typeof source === 'string' ? source : '';
  }
  const name = row['name'];
  return typeof name === 'string' ? name : '';
}

export function firstIdFromList(rows) {
  const id = rows[0]?.['id'];
  return id != null ? Number(id) : null;
}

export function findBaselineIdInList(rows, segment) {
  for (const row of rows) {
    const label = baselineLabel(row, segment);
    if (label.startsWith(E2E_BASELINE_PREFIX) && row['id'] != null) {
      return Number(row['id']);
    }
  }
  return null;
}

/** プレフィックス一致 id → なければ一覧先頭 id */
export function pickBaselineIdFromList(rows, segment) {
  return findBaselineIdInList(rows, segment) ?? firstIdFromList(rows);
}

export function pickBaselinePlanId(plans) {
  for (const plan of plans) {
    const name = plan['plan_name'];
    if (typeof name === 'string' && name.startsWith(E2E_BASELINE_PREFIX) && plan['id'] != null) {
      return Number(plan['id']);
    }
  }
  return firstIdFromList(plans);
}

/** ユーザー所有農場（is_reference: false）の件数 */
export function countUserOwnedFarms(rows) {
  return rows.filter((row) => row['is_reference'] === false).length;
}
