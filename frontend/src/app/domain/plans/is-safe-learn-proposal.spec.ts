import { beforeEach, describe, expect, it } from 'vitest';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  clearLearnProposalApplicationProgressCache,
  markBpTimingProposalDismissed,
  markLearnProposalConfirmed,
  stageGddProposalProgressKey
} from './learn-proposal-application-progress';
import {
  collectSafeLearnProposals,
  countSafeLearnProposals,
  isSafeBpTimingProposal,
  isSafeStageGddProposal
} from './is-safe-learn-proposal';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

const PLAN_ID = 7;

function stageGdd(overrides: Partial<StageGddCalibrationProposal> = {}): StageGddCalibrationProposal {
  return {
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
  };
}

function bpTiming(
  overrides: Partial<BlueprintTimingAdjustmentProposal> = {}
): BlueprintTimingAdjustmentProposal {
  return {
    cropId: 1,
    cropName: 'Tomato',
    category: 'general',
    averageDeltaDays: 2,
    averageGddDelta: null,
    recordedItemCount: 3,
    affectedBlueprintCount: 1,
    proposalBody: { stages: [], agricultural_tasks: [], task_schedule_blueprints: [] },
    ...overrides
  };
}

describe('isSafeStageGddProposal', () => {
  beforeEach(() => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
  });

  it('returns true for not_started proposal within GDD threshold with proposed value', () => {
    expect(isSafeStageGddProposal(PLAN_ID, stageGdd({ averageGddDelta: 10 }))).toBe(true);
  });

  it('returns false when average GDD delta exceeds threshold', () => {
    expect(isSafeStageGddProposal(PLAN_ID, stageGdd({ averageGddDelta: 10.1 }))).toBe(false);
  });

  it('returns false when proposal is already confirmed', () => {
    markLearnProposalConfirmed(PLAN_ID, stageGddProposalProgressKey(1, 2));
    expect(isSafeStageGddProposal(PLAN_ID, stageGdd())).toBe(false);
  });

  it('returns false when proposedRequiredGdd is null', () => {
    expect(isSafeStageGddProposal(PLAN_ID, stageGdd({ proposedRequiredGdd: null }))).toBe(false);
  });
});

describe('isSafeBpTimingProposal', () => {
  beforeEach(() => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
  });

  it('returns true for not_started proposal within days threshold', () => {
    expect(isSafeBpTimingProposal(PLAN_ID, bpTiming({ averageDeltaDays: 3 }))).toBe(true);
  });

  it('returns false when average days delta exceeds threshold', () => {
    expect(isSafeBpTimingProposal(PLAN_ID, bpTiming({ averageDeltaDays: 3.1 }))).toBe(false);
  });

  it('returns false when proposal is dismissed', () => {
    markBpTimingProposalDismissed(PLAN_ID, { cropId: 1, category: 'general' });
    expect(isSafeBpTimingProposal(PLAN_ID, bpTiming())).toBe(false);
  });
});

describe('collectSafeLearnProposals', () => {
  beforeEach(() => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
  });

  it('collects only safe proposals from both lists', () => {
    const result = collectSafeLearnProposals(PLAN_ID, [stageGdd(), stageGdd({ averageGddDelta: 20 })], [
      bpTiming(),
      bpTiming({ cropId: 2, category: 'harvest', averageDeltaDays: 5 })
    ]);

    expect(result.stageGdd).toHaveLength(1);
    expect(result.bpTiming).toHaveLength(1);
    expect(countSafeLearnProposals(PLAN_ID, [stageGdd(), stageGdd({ averageGddDelta: 20 })], [bpTiming()])).toBe(
      2
    );
  });
});
