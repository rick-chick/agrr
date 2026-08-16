import { describe, expect, it } from 'vitest';
import { collectLearnProposalRawSources } from './collect-learn-proposal-raw-sources';
import type { PlanVarianceLearningSnapshot } from './plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

const importedStageGdd = {
  crop_id: 1,
  crop_name: 'Tomato',
  stage_order: 1,
  stage_name: 'Vegetative',
  average_gdd_delta: 10,
  recorded_item_count: 2
};

const currentStageGdd = {
  crop_id: 1,
  crop_name: 'Tomato',
  stage_order: 2,
  stage_name: 'Flowering',
  average_gdd_delta: 5,
  recorded_item_count: 1
};

const importedBlueprint = {
  crop_id: 1,
  crop_name: 'Tomato',
  category: 'general',
  average_delta_days: 3,
  average_gdd_delta: 8,
  recorded_item_count: 2
};

const varianceSummary: PlanVsActualSummary = {
  plan_id: 7,
  unrecorded_count: 0,
  categories: [],
  top_variance_items: [],
  stage_gdd_calibration_proposals: [currentStageGdd],
  blueprint_timing_adjustment_proposals: []
};

const learningSnapshot: PlanVarianceLearningSnapshot = {
  plan_id: 7,
  source_plan_id: 8,
  summary: {
    plan_id: 7,
    unrecorded_count: 0,
    categories: [],
    top_variance_items: [],
    stage_gdd_calibration_proposals: [importedStageGdd],
    blueprint_timing_adjustment_proposals: [importedBlueprint]
  }
};

describe('collectLearnProposalRawSources', () => {
  it('returns imported snapshot proposals when variance summary is empty', () => {
    const result = collectLearnProposalRawSources(null, learningSnapshot);

    expect(result.stageGddCalibrationProposals).toEqual([importedStageGdd]);
    expect(result.blueprintTimingAdjustmentProposals).toEqual([importedBlueprint]);
    expect(result.blueprintAmountAdjustmentProposals).toEqual([]);
  });

  it('merges current variance and imported snapshot without duplicate keys', () => {
    const result = collectLearnProposalRawSources(varianceSummary, learningSnapshot);

    expect(result.stageGddCalibrationProposals).toEqual([importedStageGdd, currentStageGdd]);
    expect(result.blueprintTimingAdjustmentProposals).toEqual([importedBlueprint]);
    expect(result.blueprintAmountAdjustmentProposals).toEqual([]);
  });

  it('prefers current variance over imported snapshot for the same proposal key', () => {
    const overriddenImported = {
      ...importedStageGdd,
      average_gdd_delta: 99
    };
    const snapshot: PlanVarianceLearningSnapshot = {
      ...learningSnapshot,
      summary: {
        ...learningSnapshot.summary,
        stage_gdd_calibration_proposals: [overriddenImported]
      }
    };
    const current: PlanVsActualSummary = {
      ...varianceSummary,
      stage_gdd_calibration_proposals: [importedStageGdd]
    };

    const result = collectLearnProposalRawSources(current, snapshot);

    expect(result.stageGddCalibrationProposals).toEqual([importedStageGdd]);
  });
});
