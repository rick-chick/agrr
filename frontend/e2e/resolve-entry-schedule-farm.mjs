/**
 * public-plans/select-crop キャプチャ用: API 応答から farm 行を取り出す（純粋関数）。
 */

/** @typedef {{ id: number; name: string; region: string; latitude: number; longitude: number }} EntryScheduleFarm */

/** @param {unknown} rows */
export function parseFirstPublicPlanFarm(rows) {
  if (!Array.isArray(rows) || rows.length === 0) return null;
  const found = rows.find((r) => r != null && typeof r === 'object' && r.id != null);
  if (found == null) return null;
  return {
    id: Number(found.id),
    name: String(found.name ?? ''),
    region: String(found.region ?? 'jp'),
    latitude: Number(found.latitude ?? 0),
    longitude: Number(found.longitude ?? 0),
  };
}

/** @param {unknown} rows @param {number | null | undefined} preferredId */
export function parseMastersFarmForSeed(rows, preferredId) {
  if (!Array.isArray(rows) || rows.length === 0) return null;
  const withRegion = rows.filter(
    (r) =>
      r != null &&
      typeof r === 'object' &&
      r.id != null &&
      typeof r.region === 'string' &&
      r.region.length > 0,
  );
  if (withRegion.length === 0) return null;
  const preferred =
    preferredId != null
      ? withRegion.find((r) => Number(r.id) === preferredId)
      : null;
  const found = preferred ?? withRegion[0];
  return {
    id: Number(found.id),
    name: String(found.name ?? 'E2E Farm'),
    region: String(found.region),
    latitude: Number(found.latitude ?? 35.6812),
    longitude: Number(found.longitude ?? 139.7671),
  };
}

export const ENTRY_SCHEDULE_FARM_REGIONS = ['jp', 'us', 'in'];
