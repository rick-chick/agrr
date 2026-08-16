import { describe, expect, it } from 'vitest';
import { buildPlanInputGapSummary } from './build-plan-input-gap-summary';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

function sampleSummary(overrides: Partial<PlanVsActualSummary> = {}): PlanVsActualSummary {
  return {
    plan_id: 7,
    unrecorded_count: 0,
    structured_unrecorded_count: 0,
    categories: [],
    top_variance_items: [],
    ...overrides
  };
}

describe('buildPlanInputGapSummary', () => {
  it('aggregates unrecorded and action-required counts', () => {
    const summary = buildPlanInputGapSummary(
      sampleSummary({
        unrecorded_count: 3,
        structured_unrecorded_count: 2,
        action_required_items: [
          {
            item_id: 1,
            field_cultivation_id: 1,
            category: 'general',
            name: 'Task A',
            scheduled_date: '2026-06-01',
            actual_date: '2026-06-05',
            delta_days: 4,
            gdd_trigger: null,
            gdd_at_actual: null,
            gdd_delta: null,
            exceedance_kind: 'days'
          }
        ]
      })
    );

    expect(summary.unrecordedCount).toBe(3);
    expect(summary.actionRequiredCount).toBe(1);
    expect(summary.structuredUnrecordedCount).toBe(2);
  });

  it('defaults structured unrecorded count to zero when missing', () => {
    const summary = buildPlanInputGapSummary(
      sampleSummary({ unrecorded_count: 2, structured_unrecorded_count: undefined as unknown as number })
    );

    expect(summary.structuredUnrecordedCount).toBe(0);
  });

  it('defaults action-required count to zero when items are missing', () => {
    const summary = buildPlanInputGapSummary(sampleSummary({ unrecorded_count: 2 }));

    expect(summary.actionRequiredCount).toBe(0);
  });
});
