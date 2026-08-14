import { describe, expect, it } from 'vitest';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  DAYS_VARIANCE_THRESHOLD,
  GDD_VARIANCE_THRESHOLD
} from './plan-variance-thresholds';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';
import {
  countSafeLearnProposals,
  filterSafeBpTimingProposals,
  filterSafeStageGddProposals,
  isSafeBpTimingProposal,
  isSafeStageGddProposal
} from './learn-safe-proposal';

const stageGddProposal = (
  overrides: Partial<StageGddCalibrationProposal> = {}
): StageGddCalibrationProposal => ({
  cropId: 1,
  cropName: 'Tomato',
  stageId: 2,
  stageOrder: 1,
  stageName: 'Vegetative',
  averageGddDelta: 5,
  recordedItemCount: 3,
  currentRequiredGdd: 100,
  proposedRequiredGdd: 105,
  ...overrides
});

const bpTimingProposal = (
  overrides: Partial<BlueprintTimingAdjustmentProposal> = {}
): BlueprintTimingAdjustmentProposal => ({
  cropId: 1,
  cropName: 'Tomato',
  category: 'general',
  averageDeltaDays: 2,
  averageGddDelta: 5,
  recordedItemCount: 4,
  affectedBlueprintCount: 2,
  proposalBody: {
    intent: 'blueprint_timing_patch',
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: [{ blueprint_id: 10, gdd_trigger: 120 }]
  },
  ...overrides
});

describe('isSafeStageGddProposal', () => {
  it('is safe when proposed GDD exists and average delta is within threshold', () => {
    expect(isSafeStageGddProposal(stageGddProposal())).toBe(true);
    expect(
      isSafeStageGddProposal(
        stageGddProposal({ averageGddDelta: GDD_VARIANCE_THRESHOLD })
      )
    ).toBe(true);
  });

  it('is unsafe when proposed GDD is missing or delta exceeds threshold', () => {
    expect(isSafeStageGddProposal(stageGddProposal({ proposedRequiredGdd: null }))).toBe(
      false
    );
    expect(
      isSafeStageGddProposal(
        stageGddProposal({ averageGddDelta: GDD_VARIANCE_THRESHOLD + 0.1 })
      )
    ).toBe(false);
  });
});

describe('isSafeBpTimingProposal', () => {
  it('is safe when average day delta is within threshold', () => {
    expect(isSafeBpTimingProposal(bpTimingProposal())).toBe(true);
    expect(
      isSafeBpTimingProposal(
        bpTimingProposal({ averageDeltaDays: DAYS_VARIANCE_THRESHOLD })
      )
    ).toBe(true);
  });

  it('is unsafe when average day delta exceeds threshold', () => {
    expect(
      isSafeBpTimingProposal(
        bpTimingProposal({ averageDeltaDays: DAYS_VARIANCE_THRESHOLD + 0.1 })
      )
    ).toBe(false);
  });
});

describe('filterSafeLearnProposals', () => {
  it('filters only safe proposals from mixed lists', () => {
    const stageGdd = [
      stageGddProposal({ stageId: 2 }),
      stageGddProposal({ stageId: 3, averageGddDelta: 20 })
    ];
    const bpTiming = [
      bpTimingProposal({ category: 'general' }),
      bpTimingProposal({ category: 'fertilizer', averageDeltaDays: 5 })
    ];

    expect(filterSafeStageGddProposals(stageGdd)).toHaveLength(1);
    expect(filterSafeStageGddProposals(stageGdd)[0].stageId).toBe(2);
    expect(filterSafeBpTimingProposals(bpTiming)).toHaveLength(1);
    expect(filterSafeBpTimingProposals(bpTiming)[0].category).toBe('general');
    expect(countSafeLearnProposals(stageGdd, bpTiming)).toBe(2);
  });
});
