import { describe, expect, it, beforeEach } from 'vitest';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import { BLUEPRINT_TIMING_PATCH_INTENT } from './blueprint-timing-adjustment-proposal';
import {
  collectSafeLearnProposals,
  isSafeBlueprintTimingProposal,
  isSafeStageGddProposal
} from './classify-safe-learn-proposals';
import {
  clearLearnProposalApplicationProgressCache,
  markLearnProposalConfirmed,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from './learn-proposal-application-progress';
import { DAYS_VARIANCE_THRESHOLD, GDD_VARIANCE_THRESHOLD } from './plan-variance-thresholds';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

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
    intent: BLUEPRINT_TIMING_PATCH_INTENT,
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: [{ blueprint_id: 10, gdd_trigger: 120 }]
  },
  ...overrides
});

describe('classify-safe-learn-proposals', () => {
  const planId = 7;

  beforeEach(() => {
    clearLearnProposalApplicationProgressCache();
  });

  describe('isSafeStageGddProposal', () => {
    it('is safe when not started and delta is within GDD threshold', () => {
      expect(isSafeStageGddProposal(planId, stageGddProposal({ averageGddDelta: 5 }))).toBe(true);
      expect(isSafeStageGddProposal(planId, stageGddProposal({ averageGddDelta: GDD_VARIANCE_THRESHOLD }))).toBe(
        true
      );
    });

    it('is not safe when delta exceeds threshold or proposed value is missing', () => {
      expect(
        isSafeStageGddProposal(planId, stageGddProposal({ averageGddDelta: GDD_VARIANCE_THRESHOLD + 0.1 }))
      ).toBe(false);
      expect(isSafeStageGddProposal(planId, stageGddProposal({ proposedRequiredGdd: null }))).toBe(false);
    });

    it('is not safe when already applied or dismissed', () => {
      markLearnProposalConfirmed(planId, stageGddProposalProgressKey(1, 2));
      expect(isSafeStageGddProposal(planId, stageGddProposal())).toBe(false);
    });
  });

  describe('isSafeBlueprintTimingProposal', () => {
    it('is safe when not started and day delta is within threshold with patches', () => {
      expect(isSafeBlueprintTimingProposal(planId, bpTimingProposal({ averageDeltaDays: 2 }))).toBe(true);
      expect(
        isSafeBlueprintTimingProposal(planId, bpTimingProposal({ averageDeltaDays: DAYS_VARIANCE_THRESHOLD }))
      ).toBe(true);
    });

    it('is not safe when delta exceeds threshold or patches are empty', () => {
      expect(
        isSafeBlueprintTimingProposal(
          planId,
          bpTimingProposal({ averageDeltaDays: DAYS_VARIANCE_THRESHOLD + 0.1 })
        )
      ).toBe(false);
      expect(
        isSafeBlueprintTimingProposal(
          planId,
          bpTimingProposal({
            proposalBody: {
              intent: BLUEPRINT_TIMING_PATCH_INTENT,
              stages: [],
              agricultural_tasks: [],
              task_schedule_blueprints: []
            }
          })
        )
      ).toBe(false);
    });
  });

  describe('collectSafeLearnProposals', () => {
    it('returns only safe not-started proposals from both kinds', () => {
      const stageGdd = [
        stageGddProposal({ stageId: 2, averageGddDelta: 5 }),
        stageGddProposal({ stageId: 3, averageGddDelta: 50, cropId: 2 })
      ];
      const bpTiming = [
        bpTimingProposal({ category: 'general', averageDeltaDays: 2 }),
        bpTimingProposal({ category: 'fertilizer', averageDeltaDays: 10 })
      ];

      const result = collectSafeLearnProposals(planId, stageGdd, bpTiming);

      expect(result.stageGdd).toHaveLength(1);
      expect(result.stageGdd[0].stageId).toBe(2);
      expect(result.bpTiming).toHaveLength(1);
      expect(result.bpTiming[0].category).toBe('general');
      expect(result.totalCount).toBe(2);
    });

    it('excludes proposals that are already confirmed', () => {
      markLearnProposalConfirmed(planId, stageGddProposalProgressKey(1, 2));
      const result = collectSafeLearnProposals(planId, [stageGddProposal()], []);
      expect(result.totalCount).toBe(0);
      expect(resolveLearnProposalApplicationStatus(planId, stageGddProposalProgressKey(1, 2))).toBe(
        'confirmed'
      );
    });
  });
});
