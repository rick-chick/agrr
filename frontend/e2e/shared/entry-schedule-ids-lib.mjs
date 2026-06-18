/**
 * entry_schedule 公開 API 応答から Playwright 用 id を取り出す（純粋関数）。
 */

/** @param {unknown} rows */
export function firstRecordId(rows) {
  if (!Array.isArray(rows) || rows.length === 0) return null;
  const found = rows.find((r) => r != null && typeof r === 'object' && r.id != null);
  return found != null ? Number(found.id) : null;
}

/** @param {unknown} data */
export function pickEntryScheduleCropId(data) {
  if (data == null || typeof data !== 'object') return null;
  const crops = /** @type {{ crops?: unknown }} */ (data).crops;
  return firstRecordId(crops);
}
