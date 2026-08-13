import { describe, expect, it } from 'vitest';
import { countMergedLearnProposals } from './count-merged-learn-proposals';
import type { PlanVarianceLearningSnapshot } from './plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

const baseSummary: PlanVsActualSummary = {
  plan_id: 7,
  unrecorded_count: 0,
  categories: [],
  top_variance_items: []
};

describe('countMergedLearnProposals', () => {
  it('returns zero when no proposals exist', () => {
    expect(countMergedLearnProposals(null, null)).toBe(0);
    expect(countMergedLearnProposals(baseSummary, null)).toBe(0);
  });

  it('counts proposals from imported snapshot and deduplicates with variance', () => {
    const snapshot: PlanVarianceLearningSnapshot = {
      plan_id: 7,
      source_plan_id: 8,
      summary: {
        ...baseSummary,
        stage_gdd_calibration_proposals: [
          {
            crop_id: 1,
            crop_name: 'Tomato',
            stage_order: 1,
            stage_name: 'Vegetative',
            average_gdd_delta: 10,
            recorded_item_count: 2
          }
        ],
        blueprint_timing_adjustment_proposals: [
          {
            crop_id: 1,
            crop_name: 'Tomato',
            category: 'general',
            average_delta_days: 2,
            average_gdd_delta: 5,
            recorded_item_count: 3
          }
        ]
      }
    };

    expect(countMergedLearnProposals(baseSummary, snapshot)).toBe(2);
  });
});
