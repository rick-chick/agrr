/**
 * 空状態 E2E 用 API シード（e2e_empty ユーザー向け）。
 */

export const E2E_EMPTY_FARM_NAME_PREFIX = 'E2E Empty State Farm';

/**
 * @param {unknown} json
 * @returns {Record<string, unknown>[]}
 */
export function parseMasterList(json) {
  if (Array.isArray(json)) return json;
  if (json && typeof json === 'object') {
    const obj = /** @type {Record<string, unknown>} */ (json);
    for (const key of ['data', 'records', 'items', 'farms', 'crops', 'plans']) {
      const val = obj[key];
      if (Array.isArray(val)) return val;
    }
  }
  return [];
}

/**
 * @param {Record<string, unknown>[]} rows
 */
export function filterUserOwnedRows(rows) {
  return rows.filter((row) => row['is_reference'] !== true);
}

/**
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} base API origin without trailing slash
 */
export async function listUserOwnedFarms(api, base) {
  const res = await api.get(`${base}/api/v1/masters/farms`);
  if (!res.ok()) return [];
  return filterUserOwnedRows(parseMasterList(await res.json()));
}

/**
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} base
 */
export async function listUserOwnedCrops(api, base) {
  const res = await api.get(`${base}/api/v1/masters/crops`);
  if (!res.ok()) return [];
  return filterUserOwnedRows(parseMasterList(await res.json()));
}

/**
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} base
 */
export async function listUserPlans(api, base) {
  const res = await api.get(`${base}/api/v1/plans`);
  if (!res.ok()) return [];
  return parseMasterList(await res.json());
}

/**
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} base
 * @param {number} farmId
 */
export async function listFarmFields(api, base, farmId) {
  const res = await api.get(`${base}/api/v1/masters/farms/${farmId}/fields`);
  if (!res.ok()) return [];
  return parseMasterList(await res.json());
}

/**
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} base
 */
export async function deleteUserOwnedFarms(api, base) {
  const farms = await listUserOwnedFarms(api, base);
  for (const farm of farms) {
    const id = farm['id'];
    if (id == null) continue;
    await api.delete(`${base}/api/v1/masters/farms/${id}`);
  }
}

/**
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} base
 */
export async function deleteUserOwnedCrops(api, base) {
  const crops = await listUserOwnedCrops(api, base);
  for (const crop of crops) {
    const id = crop['id'];
    if (id == null) continue;
    await api.delete(`${base}/api/v1/masters/crops/${id}`);
  }
}

/**
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} base
 */
export async function deleteUserPlans(api, base) {
  const plans = await listUserPlans(api, base);
  for (const plan of plans) {
    const id = plan['id'];
    if (id == null) continue;
    await api.delete(`${base}/api/v1/plans/${id}`);
  }
}

/**
 * Idempotent: e2e_empty ユーザーの私有データをすべて削除する。
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} base
 */
export async function resetEmptyStateUserData(api, base) {
  await deleteUserPlans(api, base);
  await deleteUserOwnedCrops(api, base);
  await deleteUserOwnedFarms(api, base);
}

/**
 * 圃場 0 の農場を 1 件確保する（plans/new の no-fields ブロック用）。
 * @param {import('@playwright/test').APIRequestContext} api
 * @param {string} base
 * @returns {Promise<number | null>} farm id
 */
export async function ensureFarmWithoutFields(api, base) {
  await resetEmptyStateUserData(api, base);
  const postRes = await api.post(`${base}/api/v1/masters/farms`, {
    data: {
      farm: {
        name: `${E2E_EMPTY_FARM_NAME_PREFIX} ${Date.now()}`,
        region: 'jp',
        latitude: 35.6812,
        longitude: 139.7671,
      },
    },
    headers: { Accept: 'application/json' },
  });
  if (!postRes.ok()) {
    const text = await postRes.text().catch(() => '');
    throw new Error(`ensureFarmWithoutFields POST failed (${postRes.status()}): ${text.slice(0, 200)}`);
  }
  const created = /** @type {Record<string, unknown>} */ (await postRes.json());
  const farmId = created['id'];
  if (farmId == null) return null;
  const fields = await listFarmFields(api, base, Number(farmId));
  if (fields.length > 0) {
    throw new Error(`ensureFarmWithoutFields: expected 0 fields, got ${fields.length}`);
  }
  return Number(farmId);
}
