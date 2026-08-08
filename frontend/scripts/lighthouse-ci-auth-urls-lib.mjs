const E2E_BASELINE_PREFIX = 'E2E Baseline';

/**
 * @param {unknown} data
 * @returns {Record<string, unknown>[]}
 */
export function parsePlansList(data) {
  return Array.isArray(data) ? data : [];
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
