import { buildSegmentPostBody } from '../e2e/fixtures/ensure-e2e-baseline-bodies.mjs';
import {
  createFetchTransport,
  ensurePlanCreateReadiness,
} from '../e2e/fixtures/ensure-plan-create-ready-baseline-lib.mjs';
import {
  E2E_BASELINE_PREFIX,
  findBaselineIdInList,
  firstIdFromList,
  parseMasterList,
} from '../e2e/shared/baseline-ids-lib.mjs';

/**
 * @param {unknown} data
 * @returns {Record<string, unknown>[]}
 */
export function parsePlansList(data) {
  return Array.isArray(data) ? data : [];
}

/**
 * @param {Record<string, unknown>[]} plans
 * @returns {boolean}
 */
export function needsBaselinePlanEnsure(plans) {
  return parsePlansList(plans).length === 0;
}

/**
 * @param {Record<string, unknown>[]} plans
 * @returns {number | null}
 */
export function pickPlanIdFromPlansPayload(plans) {
  for (const plan of plans) {
    const name = plan['plan_name'];
    if (typeof name === 'string' && name.startsWith(E2E_BASELINE_PREFIX) && plan['id'] != null) {
      return Number(plan['id']);
    }
  }
  const firstId = plans[0]?.['id'];
  return firstId != null ? Number(firstId) : null;
}

/**
 * @param {{ path: string; url?: string; urlTemplate?: string }[]} templates
 * @param {number} planId
 * @returns {{ path: string; url: string }[]}
 */
export function buildAuthLighthouseUrls(templates, planId) {
  return templates.map((template) => {
    const url = template.urlTemplate
      ? template.urlTemplate.replace('{planId}', String(planId))
      : template.url;
    if (!url) {
      throw new Error(`missing url for auth route ${template.path}`);
    }
    return { path: template.path, url };
  });
}

/**
 * @param {string} base
 * @param {Record<string, string>} headers
 * @param {string} listUrl
 * @returns {Promise<Record<string, unknown>[]>}
 */
async function fetchMasterList(base, headers, listUrl) {
  const response = await fetch(`${base}${listUrl}`, { headers });
  if (!response.ok) {
    const body = await response.text();
    throw new Error(`GET ${listUrl} failed (${response.status}): ${body.slice(0, 300)}`);
  }
  return parseMasterList(await response.json());
}

/**
 * @param {string} base
 * @param {Record<string, string>} headers
 * @param {'farms' | 'crops'} segment
 * @param {{ cropId: number | null; pestId: number | null }} ctx
 * @returns {Promise<number | null>}
 */
async function ensureMasterSegment(base, headers, segment, ctx) {
  const listUrl = `/api/v1/masters/${segment}`;
  const rows = await fetchMasterList(base, headers, listUrl);
  const existing = findBaselineIdInList(rows, segment);
  if (existing != null) return existing;

  const postRes = await fetch(`${base}${listUrl}`, {
    method: 'POST',
    headers,
    body: JSON.stringify(buildSegmentPostBody(segment, ctx)),
  });
  if (postRes.ok) {
    try {
      const created = /** @type {Record<string, unknown>} */ (await postRes.json());
      if (created['id'] != null) return Number(created['id']);
    } catch {
      /* fall through */
    }
    const after = await fetchMasterList(base, headers, listUrl);
    return findBaselineIdInList(after, segment) ?? firstIdFromList(after);
  }

  const body = await postRes.text();
  throw new Error(`POST ${listUrl} failed (${postRes.status}): ${body.slice(0, 300)}`);
}

/**
 * @param {string} base
 * @param {Record<string, string>} headers
 * @param {number} farmId
 */
async function ensureFarmFieldForPlan(base, headers, farmId) {
  const listUrl = `/api/v1/masters/farms/${farmId}/fields`;
  const rows = await fetchMasterList(base, headers, listUrl);
  const hasArea = rows.some((row) => typeof row['area'] === 'number' && row['area'] > 0);
  if (hasArea) return;

  const postRes = await fetch(`${base}${listUrl}`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      field: {
        name: `${E2E_BASELINE_PREFIX} Field`,
        area: 100,
        daily_fixed_cost: 500,
      },
    }),
  });
  if (!postRes.ok) {
    const body = await postRes.text();
    throw new Error(`POST ${listUrl} failed (${postRes.status}): ${body.slice(0, 300)}`);
  }
}

/**
 * Idempotent baseline plan ensure (same intent as Playwright ensureE2eBaseline plan step).
 *
 * @param {string} apiOrigin
 * @param {string} sessionId
 */
export async function ensureBaselinePlanForLighthouse(apiOrigin, sessionId) {
  const base = apiOrigin.replace(/\/$/, '');
  const headers = {
    Cookie: `session_id=${sessionId}`,
    Accept: 'application/json',
    'Content-Type': 'application/json',
  };

  const plansResponse = await fetch(`${base}/api/v1/plans`, { headers });
  if (!plansResponse.ok) {
    const body = await plansResponse.text();
    throw new Error(`GET /api/v1/plans failed (${plansResponse.status}): ${body.slice(0, 300)}`);
  }
  const plans = parsePlansList(await plansResponse.json());
  if (!needsBaselinePlanEnsure(plans)) return;

  const farmId = await ensureMasterSegment(base, headers, 'farms', { cropId: null, pestId: null });
  const cropId = await ensureMasterSegment(base, headers, 'crops', { cropId: null, pestId: null });
  if (cropId == null) {
    throw new Error('cannot create baseline plan: missing crop_id');
  }

  const transport = createFetchTransport(base, headers);
  const readyFarmId = await ensurePlanCreateReadiness(transport, farmId, cropId);

  await ensureFarmFieldForPlan(base, headers, readyFarmId);

  const postRes = await fetch(`${base}/api/v1/plans`, {
    method: 'POST',
    headers,
    body: JSON.stringify({
      plan: {
        farm_id: readyFarmId,
        crop_ids: [cropId],
        plan_name: `${E2E_BASELINE_PREFIX} Plan`,
      },
    }),
  });
  if (!postRes.ok) {
    const body = await postRes.text();
    throw new Error(`POST /api/v1/plans failed (${postRes.status}): ${body.slice(0, 300)}`);
  }
}
