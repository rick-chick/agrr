import type { APIRequestContext } from '@playwright/test';
import {
  ENTRY_SCHEDULE_FARM_REGIONS,
  parseFirstPublicPlanFarm,
  parseMastersFarmForSeed,
} from './resolve-entry-schedule-farm.mjs';
import { pickEntryScheduleCropId } from './shared/entry-schedule-ids-lib.mjs';
import {
  MASTER_SEGMENTS,
  parseMasterList,
  pickBaselineIdFromList,
  pickBaselinePlanId,
} from './shared/baseline-ids';

export { MASTER_SEGMENTS };
export { applyResolvedUrl } from './apply-resolved-url.mjs';

export type ResolvedCaptureIds = {
  masters: Record<string, number>;
  /** GET /api/v1/plans — E2E Baseline プレフィックス優先、なければ先頭 */
  privatePlanId: number | null;
  /** GET public cultivation_plans/:id/data が 200 になる id */
  publicPlanId: number | null;
  /** GET /api/v1/public_plans/entry_schedule/farms の参照農場 id（masters/farms とは別） */
  farmId: number | null;
  /** select-crop 直着地用: entry_schedule 参照農場の実レコード */
  entryScheduleFarm: {
    id: number;
    name: string;
    region: string;
    latitude: number;
    longitude: number;
  } | null;
  cropId: number | null;
};

function stripOrigin(base: string): string {
  return base.replace(/\/$/, '');
}

async function fetchPublicPlanFarmsForRegion(
  api: APIRequestContext,
  base: string,
  path: '/api/v1/public_plans/entry_schedule/farms' | '/api/v1/public_plans/farms',
  region?: string,
): Promise<ResolvedCaptureIds['entryScheduleFarm']> {
  const url =
    region != null && region.length > 0
      ? `${base}${path}?region=${encodeURIComponent(region)}`
      : `${base}${path}`;
  const res = await api.get(url, { failOnStatusCode: false });
  if (!res.ok()) return null;
  try {
    return parseFirstPublicPlanFarm(await res.json());
  } catch {
    return null;
  }
}

async function fetchMastersFarmForSeed(
  api: APIRequestContext,
  base: string,
  masters: Record<string, number>,
): Promise<ResolvedCaptureIds['entryScheduleFarm']> {
  const res = await api.get(`${base}/api/v1/masters/farms`, { failOnStatusCode: false });
  if (!res.ok()) return null;
  try {
    return parseMastersFarmForSeed(parseMasterList(await res.json()), masters.farms ?? null);
  } catch {
    return null;
  }
}

/** select-crop 直着地シード用: 参照農場 API → リージョン試行 → masters 農場の順で解決 */
async function resolveEntryScheduleFarmForCapture(
  api: APIRequestContext,
  base: string,
  masters: Record<string, number>,
): Promise<ResolvedCaptureIds['entryScheduleFarm']> {
  const paths = [
    '/api/v1/public_plans/entry_schedule/farms',
    '/api/v1/public_plans/farms',
  ] as const;

  for (const path of paths) {
    const defaultFarm = await fetchPublicPlanFarmsForRegion(api, base, path);
    if (defaultFarm != null) return defaultFarm;

    for (const region of ENTRY_SCHEDULE_FARM_REGIONS) {
      const regionalFarm = await fetchPublicPlanFarmsForRegion(api, base, path, region);
      if (regionalFarm != null) return regionalFarm;
    }
  }

  return fetchMastersFarmForSeed(api, base, masters);
}

/** farm_id 単位でエントリ目安 API に載る作物 id（マスタ先頭 crop とは一致しないことがある） */
async function fetchEntryScheduleCropIdForFarm(
  api: APIRequestContext,
  base: string,
  farmId: number,
): Promise<number | null> {
  const res = await api.get(
    `${base}/api/v1/public_plans/entry_schedule/crops?farm_id=${farmId}&limit=20`,
    { failOnStatusCode: false },
  );
  if (!res.ok()) return null;
  try {
    return pickEntryScheduleCropId(await res.json());
  } catch {
    return null;
  }
}

/**
 * 開発セッション付き API で一覧を取り、マニフェストの placeholder `1` を差し替えるための id を集める。
 */
export async function buildResolvedCaptureIds(
  api: APIRequestContext,
  apiOrigin: string,
): Promise<ResolvedCaptureIds> {
  const base = stripOrigin(apiOrigin);
  const masters: Record<string, number> = {};

  await Promise.all(
    MASTER_SEGMENTS.map(async (seg) => {
      try {
        const res = await api.get(`${base}/api/v1/masters/${seg}`);
        if (!res.ok()) return;
        const rows = parseMasterList(await res.json());
        const id = pickBaselineIdFromList(rows, seg);
        if (id != null) masters[seg] = id;
      } catch {
        /* API 未起動・ネットワークエラー時は当該 segment のみ未解決 */
      }
    }),
  );

  let privatePlanId: number | null = null;
  try {
    const plansRes = await api.get(`${base}/api/v1/plans`);
    if (plansRes.ok()) {
      const plans = parseMasterList(await plansRes.json());
      privatePlanId = pickBaselinePlanId(plans);
    }
  } catch {
    /* ignore */
  }

  const entryScheduleFarm = await resolveEntryScheduleFarmForCapture(api, base, masters);
  const farmId = entryScheduleFarm?.id ?? null;
  let cropId: number | null = null;
  if (farmId != null) {
    cropId = await fetchEntryScheduleCropIdForFarm(api, base, farmId);
  }

  const publicPlanId = await probePublicPlanId(api, base);

  return { masters, privatePlanId, publicPlanId, farmId, entryScheduleFarm, cropId };
}

/** 認証不要の public data が取れる cultivation_plan id を少数試行で探す */
async function probePublicPlanId(api: APIRequestContext, base: string): Promise<number | null> {
  const max = Number(process.env.E2E_PUBLIC_PLAN_PROBE_MAX ?? '48');
  for (let id = 1; id <= max; id++) {
    const res = await api.get(`${base}/api/v1/public_plans/cultivation_plans/${id}/data`, {
      failOnStatusCode: false,
    });
    if (res.status() === 200) return id;
  }
  return null;
}
