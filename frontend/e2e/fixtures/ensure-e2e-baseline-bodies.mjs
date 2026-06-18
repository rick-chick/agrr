/** @typedef {'farms' | 'crops' | 'pests' | 'pesticides' | 'fertilizes' | 'agricultural_tasks' | 'interaction_rules'} MasterSegment */

export const E2E_BASELINE_PREFIX = 'E2E Baseline';

/**
 * Rust masters API は segment 名の単数ラッパを要求する（例: `{ agricultural_task: { ... } }`）。
 * @param {MasterSegment} segment
 * @param {{ cropId: number | null; pestId: number | null }} ctx
 */
export function buildSegmentPostBody(segment, ctx) {
  switch (segment) {
    case 'farms':
      return {
        farm: {
          name: `${E2E_BASELINE_PREFIX} Farm`,
          region: 'jp',
          latitude: 35.6812,
          longitude: 139.7671,
        },
      };
    case 'crops':
      return {
        crop: {
          name: `${E2E_BASELINE_PREFIX} Crop`,
          variety: 'smoke',
          area_per_unit: 0.25,
          revenue_per_area: 5000,
        },
      };
    case 'pests':
      return {
        pest: {
          name: `${E2E_BASELINE_PREFIX} Pest`,
          name_scientific: 'E2e baseline pest',
          family: 'E2E',
        },
      };
    case 'pesticides':
      return {
        pesticide: {
          name: `${E2E_BASELINE_PREFIX} Pesticide`,
          active_ingredient: 'e2e',
          crop_id: ctx.cropId,
          pest_id: ctx.pestId,
        },
      };
    case 'fertilizes':
      return {
        fertilize: {
          name: `${E2E_BASELINE_PREFIX} Fertilize`,
          n: 10,
          p: 5,
          k: 5,
          package_size: 25,
        },
      };
    case 'agricultural_tasks':
      return {
        agricultural_task: {
          name: `${E2E_BASELINE_PREFIX} Task`,
          description: 'E2E smoke baseline',
          time_per_sqm: 0.5,
        },
      };
    case 'interaction_rules':
      return {
        interaction_rule: {
          rule_type: 'continuous_cultivation',
          source_group: `${E2E_BASELINE_PREFIX} Source`,
          target_group: `${E2E_BASELINE_PREFIX} Target`,
          impact_ratio: 0.7,
        },
      };
    default:
      throw new Error(`unknown segment: ${segment}`);
  }
}

/** @param {unknown} body */
export function topLevelWrapperKey(body) {
  if (body == null || typeof body !== 'object') return null;
  const keys = Object.keys(body);
  return keys.length === 1 ? keys[0] : null;
}
