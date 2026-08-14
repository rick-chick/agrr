import { describe, expect, it } from 'vitest';
import { buildPlanWorkVarianceSummaryStats } from './build-plan-work-variance-summary-stats';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

function sampleSummary(
  overrides: Partial<PlanVsActualSummary> = {}
): PlanVsActualSummary {
  return {
    plan_id: 7,
    unrecorded_count: 2,
    categories: [],
    top_variance_items: [],
    action_required_items: [],
    ...overrides
  };
}

describe('buildPlanWorkVarianceSummaryStats', () => {
  it('counts unrecorded, threshold exceedance, and GDD delay items', () => {
    const stats = buildPlanWorkVarianceSummaryStats(
      sampleSummary({
        unrecorded_count: 3,
        action_required_items: [
          {
            item_id: 1,
            field_cultivation_id: 10,
            category: 'field_work',
            name: '追肥',
            scheduled_date: '2026-06-01',
            actual_date: '2026-06-08',
            delta_days: 7,
            gdd_trigger: 100,
            gdd_at_actual: 120,
            gdd_delta: 20,
            exceedance_kind: 'both'
          },
          {
            item_id: 2,
            field_cultivation_id: 11,
            category: 'field_work',
            name: '除草',
            scheduled_date: '2026-06-02',
            actual_date: '2026-06-03',
            delta_days: 1,
            gdd_trigger: 50,
            gdd_at_actual: 65,
            gdd_delta: 15,
            exceedance_kind: 'gdd'
          },
          {
            item_id: 3,
            field_cultivation_id: 12,
            category: 'field_work',
            name: '収穫',
            scheduled_date: '2026-06-03',
            actual_date: '2026-06-10',
            delta_days: 7,
            gdd_trigger: null,
            gdd_at_actual: null,
            gdd_delta: null,
            exceedance_kind: 'days'
          }
        ]
      })
    );

    expect(stats).toEqual({
      unrecordedCount: 3,
      thresholdExceedanceCount: 3,
      gddDelayCount: 2
    });
  });

  it('returns zero counts when action_required_items is absent', () => {
    const stats = buildPlanWorkVarianceSummaryStats(sampleSummary({ unrecorded_count: 0 }));

    expect(stats).toEqual({
      unrecordedCount: 0,
      thresholdExceedanceCount: 0,
      gddDelayCount: 0
    });
  });
});
