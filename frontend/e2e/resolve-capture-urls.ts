import type { APIRequestContext } from '@playwright/test';
import {
  MASTER_SEGMENTS,
  parseMasterList,
  pickBaselineIdFromList,
  pickBaselinePlanId,
} from './shared/baseline-ids';
import { type ResolvedCaptureIds } from './shared/apply-resolved-url';

export { MASTER_SEGMENTS } from './shared/baseline-ids';
export { applyResolvedUrl, type ResolvedCaptureIds } from './shared/apply-resolved-url';

function stripOrigin(base: string): string {
  return base.replace(/\/$/, '');
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
    const data = (await res.json()) as { crops?: Array<{ id?: unknown }> };
    const crops = data?.crops;
    if (!Array.isArray(crops) || crops.length === 0) return null;
    const first = crops.find((c) => c?.id != null);
    return first != null ? Number(first.id) : null;
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

  const farmId = masters['farms'] ?? null;
  let cropId: number | null = null;
  if (farmId != null) {
    cropId = await fetchEntryScheduleCropIdForFarm(api, base, farmId);
  }

  const publicPlanId = await probePublicPlanId(api, base);

  return { masters, privatePlanId, publicPlanId, farmId, cropId };
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
