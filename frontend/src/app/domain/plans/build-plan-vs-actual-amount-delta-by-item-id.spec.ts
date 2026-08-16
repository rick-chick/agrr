import { describe, expect, it } from 'vitest';
import { buildPlanVsActualAmountDeltaByItemId } from './build-plan-vs-actual-amount-delta-by-item-id';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

describe('buildPlanVsActualAmountDeltaByItemId', () => {
  it('indexes amount_delta from top variance and action required items', () => {
    const summary: PlanVsActualSummary = {
      plan_id: 7,
      unrecorded_count: 0,
      categories: [],
      top_variance_items: [
        {
          item_id: 10,
          field_cultivation_id: 1,
          category: 'fertilizer',
          name: 'Basal',
          scheduled_date: '2026-06-01',
          actual_date: '2026-06-02',
          delta_days: 1,
          gdd_trigger: null,
          gdd_at_actual: null,
          gdd_delta: null,
          amount_delta: 0.5
        }
      ],
      action_required_items: [
        {
          item_id: 20,
          field_cultivation_id: 1,
          category: 'pest_control',
          name: 'Spray',
          scheduled_date: '2026-06-03',
          actual_date: '2026-06-03',
          delta_days: 0,
          gdd_trigger: null,
          gdd_at_actual: null,
          gdd_delta: null,
          exceedance_kind: 'days',
          amount_delta: -1.0
        }
      ]
    };

    expect(buildPlanVsActualAmountDeltaByItemId(summary)).toEqual({
      10: 0.5,
      20: -1.0
    });
  });
});
