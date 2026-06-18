import { request, type APIRequestContext } from '@playwright/test';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { buildSegmentPostBody } from './ensure-e2e-baseline-bodies.mjs';
import {
  E2E_BASELINE_PREFIX,
  findBaselineIdInList,
  firstIdFromList,
  parseMasterList,
  type JsonRecord,
  type MasterSegment,
} from '../shared/baseline-ids';

function apiOrigin(): string {
  return (process.env.E2E_API_ORIGIN ?? 'http://127.0.0.1:4200').replace(/\/$/, '');
}

function sessionStoragePath(): string {
  return join(process.cwd(), 'e2e', '.auth', 'dev-session.json');
}

async function createApiContext(): Promise<APIRequestContext | null> {
  const path = sessionStoragePath();
  if (!existsSync(path)) {
    return null;
  }
  return request.newContext({ storageState: path });
}

async function parseList(res: Awaited<ReturnType<APIRequestContext['get']>>): Promise<JsonRecord[]> {
  if (!res.ok()) return [];
  try {
    return parseMasterList(await res.json());
  } catch {
    return [];
  }
}

type SegmentConfig = {
  segment: MasterSegment;
};

const SEGMENT_CONFIGS: SegmentConfig[] = [
  { segment: 'farms' },
  { segment: 'crops' },
  { segment: 'pests' },
  { segment: 'pesticides' },
  { segment: 'fertilizes' },
  { segment: 'agricultural_tasks' },
  { segment: 'interaction_rules' },
];

async function ensureMasterSegment(
  api: APIRequestContext,
  base: string,
  config: SegmentConfig,
  ctx: { cropId: number | null; pestId: number | null },
): Promise<number | null> {
  const listUrl = `${base}/api/v1/masters/${config.segment}`;
  const rows = await parseList(await api.get(listUrl));
  const existing = findBaselineIdInList(rows, config.segment);
  if (existing != null) return existing;

  const postBody = buildSegmentPostBody(config.segment, ctx);
  if (config.segment === 'pesticides' && (ctx.cropId == null || ctx.pestId == null)) {
    console.warn(`[ensureE2eBaseline] skip pesticides POST: missing crop_id or pest_id`);
    return firstIdFromList(rows);
  }

  const postRes = await api.post(listUrl, {
    data: postBody,
    headers: { Accept: 'application/json' },
  });
  if (postRes.ok()) {
    try {
      const created = (await postRes.json()) as JsonRecord;
      if (created['id'] != null) return Number(created['id']);
    } catch {
      /* fall through */
    }
    const after = await parseList(await api.get(listUrl));
    const createdId = findBaselineIdInList(after, config.segment) ?? firstIdFromList(after);
    if (createdId != null) return createdId;
  }

  const status = postRes.status();
  const text = await postRes.text().catch(() => '');
  console.warn(
    `[ensureE2eBaseline] POST ${config.segment} failed (${status}): ${text.slice(0, 200)}`,
  );
  return firstIdFromList(rows);
}

/** plan POST は farm の圃場面積合計 > 0 が必要。baseline farm に圃場が無いとき 1 件作る。 */
async function ensureFarmFieldForPlan(
  api: APIRequestContext,
  base: string,
  farmId: number,
): Promise<void> {
  const listUrl = `${base}/api/v1/masters/farms/${farmId}/fields`;
  const rows = await parseList(await api.get(listUrl));
  const hasArea = rows.some((row) => {
    const area = row['area'];
    return typeof area === 'number' && area > 0;
  });
  if (hasArea) return;

  const postRes = await api.post(listUrl, {
    data: {
      field: {
        name: `${E2E_BASELINE_PREFIX} Field`,
        area: 100,
        daily_fixed_cost: 500,
      },
    },
    headers: { Accept: 'application/json' },
  });
  if (!postRes.ok()) {
    const status = postRes.status();
    const text = await postRes.text().catch(() => '');
    console.warn(`[ensureE2eBaseline] POST field failed (${status}): ${text.slice(0, 200)}`);
  }
}

async function ensurePlan(
  api: APIRequestContext,
  base: string,
  farmId: number | null,
  cropId: number | null,
): Promise<void> {
  const listUrl = `${base}/api/v1/plans`;
  const res = await api.get(listUrl);
  let plans: JsonRecord[] = [];
  if (res.ok()) {
    try {
      plans = parseMasterList(await res.json());
    } catch {
      /* ignore */
    }
  }

  const baselinePlan = plans.find((p) => {
    const name = p['plan_name'];
    return typeof name === 'string' && name.startsWith(E2E_BASELINE_PREFIX);
  });
  if (baselinePlan?.['id'] != null) return;

  if (plans.length > 0) return;

  if (farmId == null || cropId == null) {
    console.warn('[ensureE2eBaseline] skip plan POST: missing farm_id or crop_id');
    return;
  }

  await ensureFarmFieldForPlan(api, base, farmId);

  const postRes = await api.post(listUrl, {
    data: {
      plan: {
        farm_id: farmId,
        crop_ids: [cropId],
        plan_name: `${E2E_BASELINE_PREFIX} Plan`,
      },
    },
    headers: { Accept: 'application/json' },
  });
  if (!postRes.ok()) {
    const status = postRes.status();
    const text = await postRes.text().catch(() => '');
    console.warn(`[ensureE2eBaseline] POST plan failed (${status}): ${text.slice(0, 200)}`);
  }
}

/**
 * Playwright session API で MASTER_SEGMENTS 全7種 + private Plan を idempotent に確保する。
 * `loadResolvedCaptureIds` の前後で smoke beforeAll から呼ぶ。
 */
export async function ensureE2eBaseline(): Promise<void> {
  const api = await createApiContext();
  if (api == null) {
    console.warn('[ensureE2eBaseline] dev-session.json missing; skipped');
    return;
  }

  const base = apiOrigin();
  try {
    let cropId: number | null = null;
    let pestId: number | null = null;
    let farmId: number | null = null;

    for (const config of SEGMENT_CONFIGS) {
      if (config.segment === 'pesticides') continue;
      const id = await ensureMasterSegment(api, base, config, { cropId, pestId });
      if (config.segment === 'farms') farmId = id;
      if (config.segment === 'crops') cropId = id;
      if (config.segment === 'pests') pestId = id;
    }

    const pesticideConfig = SEGMENT_CONFIGS.find((c) => c.segment === 'pesticides');
    if (pesticideConfig) {
      await ensureMasterSegment(api, base, pesticideConfig, { cropId, pestId });
    }

    await ensurePlan(api, base, farmId, cropId);
  } finally {
    await api.dispose();
  }
}
