import { MASTER_SEGMENTS } from './baseline-ids';

export type ResolvedCaptureIds = {
  masters: Record<string, number>;
  privatePlanId: number | null;
  publicPlanId: number | null;
  farmId: number | null;
  cropId: number | null;
};

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
    const f = ids.farmId ?? 1;
    if (ids.cropId != null) {
      return `/entry-schedule/crop/${ids.cropId}?farmId=${f}`;
    }
    return url;
  }

  if (pattern.startsWith('plans/')) {
    const p = ids.privatePlanId;
    if (p == null) return url;
    if (pattern === 'plans/:id') return `/plans/${p}`;
    if (pattern === 'plans/:id/optimizing') return `/plans/${p}/optimizing`;
    if (pattern === 'plans/:id/task_schedule') return `/plans/${p}/task_schedule`;
    if (pattern === 'plans/:id/work') return `/plans/${p}/work`;
    if (pattern === 'plans/:id/work_records') return `/plans/${p}/work_records`;
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
