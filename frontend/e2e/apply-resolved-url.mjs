/** GET /api/v1/masters/:segment の URL セグメント（resolve-capture-urls と共有） */
export const MASTER_SEGMENTS = [
  'agricultural_tasks',
  'crops',
  'farms',
  'fertilizes',
  'interaction_rules',
  'pesticides',
  'pests',
];

/**
 * route-manifest.json の静的 url を、buildResolvedCaptureIds の結果で上書きする。
 * 部分文字列置換は多桁 id で誤爆するため、pattern からパスを組み立てる。
 *
 * @param {string} pattern
 * @param {string} url
 * @param {{
 *   masters: Record<string, number>;
 *   privatePlanId: number | null;
 *   publicPlanId: number | null;
 *   farmId: number | null;
 *   cropId: number | null;
 *   cropStageEdit: { cropId: number; stageId: number } | null;
 * }} ids
 * @returns {string}
 */
export function applyResolvedUrl(pattern, url, ids) {
  if (pattern.startsWith('public-plans/') && url.includes('planId=')) {
    if (ids.publicPlanId == null) return url;
    return url.replace(/planId=\d+/, `planId=${ids.publicPlanId}`);
  }

  if (pattern === 'entry-schedule/crop/:cropId') {
    if (ids.cropId == null || ids.farmId == null) return url;
    return `/entry-schedule/crop/${ids.cropId}?farmId=${ids.farmId}`;
  }

  if (pattern === 'crops/:id/stages') {
    const target = ids.cropStageEdit;
    if (target == null) return url;
    return `/crops/${target.cropId}/stages`;
  }

  if (pattern === 'crops/:id/stages/:stageId/edit') {
    const target = ids.cropStageEdit;
    if (target == null) return url;
    return `/crops/${target.cropId}/stages/${target.stageId}/edit`;
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
