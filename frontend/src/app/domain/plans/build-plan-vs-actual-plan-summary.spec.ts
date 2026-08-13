import { describe, expect, it } from 'vitest';

import { buildPlanVsActualPlanSummaryStats } from './build-plan-vs-actual-plan-summary';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

function sampleSummary(
  overrides: Partial<PlanVsActualSummary> = {}
): PlanVsActualSummary {
  return {
    plan_id: 7,
    unrecorded_count: 2,
    categories: [
      {
        category: 'general',
        average_delta_days: 3,
        item_count: 4,
        recorded_count: 2
      },
      {
        category: 'fertilizer',
        average_delta_days: -1,
        item_count: 2,
        recorded_count: 1
      }
    ],
    top_variance_items: [],
    stage_gdd_calibration_proposals: [],
    ...overrides
  };
}

describe('buildPlanVsActualPlanSummaryStats', () => {
  it('aggregates completed count and weighted average delta across categories', () => {
    const stats = buildPlanVsActualPlanSummaryStats(sampleSummary());

    expect(stats.completedCount).toBe(3);
    expect(stats.unrecordedCount).toBe(2);
    expect(stats.averageDeltaDays).toBeCloseTo((3 * 2 + -1 * 1) / 3);
  });

  it('returns null average when no recorded items exist', () => {
    const stats = buildPlanVsActualPlanSummaryStats(
      sampleSummary({
        categories: [
          {
            category: 'general',
            average_delta_days: 5,
            item_count: 2,
            recorded_count: 0
          }
        ],
        unrecorded_count: 2
      })
    );

    expect(stats.completedCount).toBe(0);
    expect(stats.averageDeltaDays).toBeNull();
  });
});
