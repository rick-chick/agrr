import { describe, expect, it, beforeEach } from 'vitest';
import type { BlueprintAmountAdjustmentProposal } from './blueprint-amount-adjustment-proposal';
import { BLUEPRINT_AMOUNT_PATCH_INTENT } from './blueprint-amount-adjustment-proposal';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import { BLUEPRINT_TIMING_PATCH_INTENT } from './blueprint-timing-adjustment-proposal';
import {
  collectSafeLearnProposals,
  isSafeBlueprintAmountProposal,
  isSafeBlueprintTimingProposal,
  isSafeStageGddProposal
} from './classify-safe-learn-proposals';
import {
  bpAmountProposalProgressKey,
  clearLearnProposalApplicationProgressCache,
  markLearnProposalConfirmed,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from './learn-proposal-application-progress';
import {
  DAYS_VARIANCE_THRESHOLD,
  FERTILIZER_AMOUNT_DELTA_THRESHOLD,
  GDD_VARIANCE_THRESHOLD,
  PEST_CONTROL_AMOUNT_DELTA_THRESHOLD
} from './plan-variance-thresholds';
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

const bpAmountProposal = (
  overrides: Partial<BlueprintAmountAdjustmentProposal> = {}
): BlueprintAmountAdjustmentProposal => ({
  cropId: 1,
  cropName: 'Tomato',
  category: 'fertilizer',
  taskType: 'fertilize',
  stageOrder: 1,
  stageName: 'Vegetative',
  averageAmountDelta: 0.4,
  recordedItemCount: 3,
  amountUnit: 'kg',
  affectedBlueprintCount: 1,
  proposalBody: {
    intent: BLUEPRINT_AMOUNT_PATCH_INTENT,
    stages: [],
    agricultural_tasks: [],
    task_schedule_blueprints: [{ blueprint_id: 10, amount: 2.5, amount_unit: 'kg' }]
  },
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

  describe('isSafeBlueprintAmountProposal', () => {
    it('is safe when not started and delta is within category threshold with patches', () => {
      expect(
        isSafeBlueprintAmountProposal(
          planId,
          bpAmountProposal({ averageAmountDelta: 0.4, category: 'fertilizer' })
        )
      ).toBe(true);
      expect(
        isSafeBlueprintAmountProposal(
          planId,
          bpAmountProposal({
            averageAmountDelta: FERTILIZER_AMOUNT_DELTA_THRESHOLD,
            category: 'fertilizer'
          })
        )
      ).toBe(true);
      expect(
        isSafeBlueprintAmountProposal(
          planId,
          bpAmountProposal({
            averageAmountDelta: PEST_CONTROL_AMOUNT_DELTA_THRESHOLD,
            category: 'pest_control'
          })
        )
      ).toBe(true);
    });

    it('is not safe when delta exceeds category threshold or patches are empty', () => {
      expect(
        isSafeBlueprintAmountProposal(
          planId,
          bpAmountProposal({
            averageAmountDelta: FERTILIZER_AMOUNT_DELTA_THRESHOLD + 0.1,
            category: 'fertilizer'
          })
        )
      ).toBe(false);
      expect(
        isSafeBlueprintAmountProposal(
          planId,
          bpAmountProposal({
            averageAmountDelta: PEST_CONTROL_AMOUNT_DELTA_THRESHOLD + 0.1,
            category: 'pest_control'
          })
        )
      ).toBe(false);
      expect(
        isSafeBlueprintAmountProposal(
          planId,
          bpAmountProposal({
            proposalBody: {
              intent: BLUEPRINT_AMOUNT_PATCH_INTENT,
              stages: [],
              agricultural_tasks: [],
              task_schedule_blueprints: []
            }
          })
        )
      ).toBe(false);
    });

    it('is not safe when already confirmed', () => {
      markLearnProposalConfirmed(
        planId,
        bpAmountProposalProgressKey(1, 'fertilizer', 'fertilize', 1)
      );
      expect(isSafeBlueprintAmountProposal(planId, bpAmountProposal())).toBe(false);
    });
  });

  describe('collectSafeLearnProposals', () => {
    it('returns only safe not-started proposals from all kinds', () => {
      const stageGdd = [
        stageGddProposal({ stageId: 2, averageGddDelta: 5 }),
        stageGddProposal({ stageId: 3, averageGddDelta: 50, cropId: 2 })
      ];
      const bpTiming = [
        bpTimingProposal({ category: 'general', averageDeltaDays: 2 }),
        bpTimingProposal({ category: 'fertilizer', averageDeltaDays: 10 })
      ];
      const bpAmount = [
        bpAmountProposal({ category: 'fertilizer', averageAmountDelta: 0.4 }),
        bpAmountProposal({ category: 'fertilizer', averageAmountDelta: 2.5, taskType: 'topdress' })
      ];

      const result = collectSafeLearnProposals(planId, stageGdd, bpTiming, bpAmount);

      expect(result.stageGdd).toHaveLength(1);
      expect(result.stageGdd[0].stageId).toBe(2);
      expect(result.bpTiming).toHaveLength(1);
      expect(result.bpTiming[0].category).toBe('general');
      expect(result.bpAmount).toHaveLength(1);
      expect(result.bpAmount[0].taskType).toBe('fertilize');
      expect(result.totalCount).toBe(3);
    });

    it('excludes proposals that are already confirmed', () => {
      markLearnProposalConfirmed(planId, stageGddProposalProgressKey(1, 2));
      const result = collectSafeLearnProposals(planId, [stageGddProposal()], [], []);
      expect(result.totalCount).toBe(0);
      expect(resolveLearnProposalApplicationStatus(planId, stageGddProposalProgressKey(1, 2))).toBe(
        'confirmed'
      );
    });
  });
});
