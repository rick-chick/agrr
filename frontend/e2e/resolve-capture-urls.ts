import type { APIRequestContext } from '@playwright/test';

/** GET /api/v1/masters/:segment から取った先頭 id（segment は URL セグメントと一致） */
const MASTER_SEGMENTS = [
  'agricultural_tasks',
  'crops',
  'farms',
  'fertilizes',
  'interaction_rules',
  'pesticides',
  'pests',
] as const;

export type ResolvedCaptureIds = {
  masters: Record<string, number>;
  /** GET /api/v1/plans の先頭（private） */
  privatePlanId: number | null;
  /** GET public cultivation_plans/:id/data が 200 になる id */
  publicPlanId: number | null;
  farmId: number | null;
  cropId: number | null;
};

function stripOrigin(base: string): string {
  return base.replace(/\/$/, '');
}

async function jsonArrayFirstId(res: Awaited<ReturnType<APIRequestContext['get']>>): Promise<number | null> {
  if (!res.ok()) return null;
  try {
    const data = await res.json();
    if (Array.isArray(data) && data[0]?.id != null) return Number(data[0].id);
  } catch {
    /* ignore */
  }
  return null;
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
      const res = await api.get(`${base}/api/v1/masters/${seg}`);
      const id = await jsonArrayFirstId(res);
      if (id != null) masters[seg] = id;
    }),
  );

  let privatePlanId: number | null = null;
  const plansRes = await api.get(`${base}/api/v1/plans`);
  if (plansRes.ok()) {
    try {
      const plans = await plansRes.json();
      if (Array.isArray(plans) && plans[0]?.id != null) privatePlanId = Number(plans[0].id);
    } catch {
      /* ignore */
    }
  }

  const farmId = masters['farms'] ?? null;
  const cropId = masters['crops'] ?? null;

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

/**
 * route-manifest.json の静的 url を、buildResolvedCaptureIds の結果で上書きする。
 * 部分文字列置換は多桁 id で誤爆するため、pattern からパスを組み立てる。
 */
export function applyResolvedUrl(pattern: string, url: string, ids: ResolvedCaptureIds): string {
  if (pattern.startsWith('public-plans/') && url.includes('planId=')) {
    const pid = ids.publicPlanId ?? 1;
    return url.replace(/planId=\d+/, `planId=${pid}`);
  }

  if (pattern === 'entry-schedule/crop/:cropId') {
    const c = ids.cropId ?? 1;
    const f = ids.farmId ?? 1;
    return `/entry-schedule/crop/${c}?farmId=${f}`;
  }

  if (pattern.startsWith('plans/')) {
    const p = ids.privatePlanId;
    if (p == null) return url;
    if (pattern === 'plans/:id') return `/plans/${p}`;
    if (pattern === 'plans/:id/optimizing') return `/plans/${p}/optimizing`;
    if (pattern === 'plans/:id/task_schedule') return `/plans/${p}/task_schedule`;
    return url;
  }

  for (const resource of MASTER_SEGMENTS) {
    if (pattern === `${resource}/:id`) {
      const mid = ids.masters[resource];
      if (mid == null) return url;
      return `/${resource}/${mid}`;
    }
    if (pattern === `${resource}/:id/edit`) {
      const mid = ids.masters[resource];
      if (mid == null) return url;
      return `/${resource}/${mid}/edit`;
    }
  }

  return url;
}
