/** GET /api/v1/masters/:segment の URL セグメント（resolve-capture-urls と共有） */
export const MASTER_SEGMENTS = [
  'agricultural_tasks',
  'crops',
  'farms',
  'fertilizes',
  'interaction_rules',
  'pesticides',
  'pests',
] as const;

export type MasterSegment = (typeof MASTER_SEGMENTS)[number];

export const E2E_BASELINE_PREFIX = 'E2E Baseline';

export type JsonRecord = Record<string, unknown>;

export function parseMasterList(data: unknown): JsonRecord[] {
  return Array.isArray(data) ? (data as JsonRecord[]) : [];
}

export function baselineLabel(row: JsonRecord, segment: MasterSegment): string {
  if (segment === 'interaction_rules') {
    const source = row['source_group'];
    return typeof source === 'string' ? source : '';
  }
  const name = row['name'];
  return typeof name === 'string' ? name : '';
}

export function firstIdFromList(rows: JsonRecord[]): number | null {
  const id = rows[0]?.['id'];
  return id != null ? Number(id) : null;
}

export function findBaselineIdInList(rows: JsonRecord[], segment: MasterSegment): number | null {
  for (const row of rows) {
    const label = baselineLabel(row, segment);
    if (label.startsWith(E2E_BASELINE_PREFIX) && row['id'] != null) {
      return Number(row['id']);
    }
  }
  return null;
}

/** プレフィックス一致 id → なければ一覧先頭 id */
export function pickBaselineIdFromList(rows: JsonRecord[], segment: MasterSegment): number | null {
  return findBaselineIdInList(rows, segment) ?? firstIdFromList(rows);
}

export function pickBaselinePlanId(plans: JsonRecord[]): number | null {
  for (const plan of plans) {
    const name = plan['plan_name'];
    if (typeof name === 'string' && name.startsWith(E2E_BASELINE_PREFIX) && plan['id'] != null) {
      return Number(plan['id']);
    }
  }
  return firstIdFromList(plans);
}

/** ユーザー所有農場（is_reference: false）の件数 */
export function countUserOwnedFarms(rows: JsonRecord[]): number {
  return rows.filter((row) => row['is_reference'] === false).length;
}
