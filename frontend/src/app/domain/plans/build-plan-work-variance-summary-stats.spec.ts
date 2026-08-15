import { describe, expect, it } from 'vitest';

import { buildPlanWorkVarianceSummaryStats } from './build-plan-work-variance-summary-stats';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

function sampleSummary(
  overrides: Partial<PlanVsActualSummary> = {}
): PlanVsActualSummary {
  return {
    plan_id: 7,
    unrecorded_count: 3,
    categories: [],
    top_variance_items: [],
    action_required_items: [
      {
        item_id: 1,
        field_cultivation_id: 10,
        category: 'general',
        name: '追肥',
        scheduled_date: '2026-06-01',
        actual_date: '2026-06-10',
        delta_days: 5,
        gdd_trigger: 100,
        gdd_at_actual: 120,
        gdd_delta: 15,
        exceedance_kind: 'both'
      },
      {
        item_id: 2,
        field_cultivation_id: 10,
        category: 'general',
        name: '除草',
        scheduled_date: '2026-06-02',
        actual_date: '2026-06-08',
        delta_days: 2,
        gdd_trigger: 50,
        gdd_at_actual: 65,
        gdd_delta: 12,
        exceedance_kind: 'gdd'
      },
      {
        item_id: 3,
        field_cultivation_id: 11,
        category: 'fertilizer',
        name: '施肥',
        scheduled_date: '2026-06-03',
        actual_date: '2026-06-10',
        delta_days: 4,
        gdd_trigger: null,
        gdd_at_actual: null,
        gdd_delta: null,
        exceedance_kind: 'days'
      }
    ],
    ...overrides
  };
}

describe('buildPlanWorkVarianceSummaryStats', () => {
  it('aggregates unrecorded, threshold exceeded, and gdd delay counts', () => {
    const stats = buildPlanWorkVarianceSummaryStats(sampleSummary());

    expect(stats.unrecordedCount).toBe(3);
    expect(stats.thresholdExceededCount).toBe(3);
    expect(stats.gddDelayCount).toBe(2);
    expect(stats.daysExceedanceCount).toBe(2);
  });

  it('returns zero counts when action_required_items is missing', () => {
    const stats = buildPlanWorkVarianceSummaryStats(
      sampleSummary({ action_required_items: undefined, unrecorded_count: 0 })
    );

    expect(stats.unrecordedCount).toBe(0);
    expect(stats.thresholdExceededCount).toBe(0);
    expect(stats.gddDelayCount).toBe(0);
    expect(stats.daysExceedanceCount).toBe(0);
  });
});
