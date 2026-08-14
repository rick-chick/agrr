import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  bpTimingProposalProgressKey,
  clearLearnProposalApplicationProgressCache,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from '../../domain/plans/learn-proposal-application-progress';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import { CROP_SETUP_PROPOSAL_GATEWAY } from '../crops/crop-setup-proposal-gateway';
import { CROP_STAGE_GATEWAY } from '../crops/crop-stage-gateway';
import { BulkApplySafeLearnProposalsUseCase } from './bulk-apply-safe-learn-proposals.usecase';

const PLAN_ID = 7;

function stageGdd(): StageGddCalibrationProposal {
  return {
    cropId: 1,
    cropName: 'Tomato',
    stageId: 2,
    stageOrder: 1,
    stageName: 'Vegetative',
    averageGddDelta: 5,
    recordedItemCount: 3,
    currentRequiredGdd: 100,
    proposedRequiredGdd: 105
  };
}

function bpTiming(): BlueprintTimingAdjustmentProposal {
  return {
    cropId: 3,
    cropName: 'Pepper',
    category: 'general',
    averageDeltaDays: 2,
    averageGddDelta: null,
    recordedItemCount: 2,
    affectedBlueprintCount: 1,
    proposalBody: { stages: [], agricultural_tasks: [], task_schedule_blueprints: [] }
  };
}

describe('BulkApplySafeLearnProposalsUseCase', () => {
  let useCase: BulkApplySafeLearnProposalsUseCase;
  let cropStageGateway: {
    getThermalRequirement: ReturnType<typeof vi.fn>;
    updateThermalRequirement: ReturnType<typeof vi.fn>;
    createThermalRequirement: ReturnType<typeof vi.fn>;
  };
  let setupProposalGateway: { apply: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
    cropStageGateway = {
      getThermalRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 2, required_gdd: 100 })),
      updateThermalRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 2, required_gdd: 105 })),
      createThermalRequirement: vi.fn()
    };
    setupProposalGateway = {
      apply: vi.fn(() => of({ valid: true }))
    };

    TestBed.configureTestingModule({
      providers: [
        BulkApplySafeLearnProposalsUseCase,
        { provide: CROP_STAGE_GATEWAY, useValue: cropStageGateway },
        { provide: CROP_SETUP_PROPOSAL_GATEWAY, useValue: setupProposalGateway }
      ]
    });
    useCase = TestBed.inject(BulkApplySafeLearnProposalsUseCase);
  });

  it('applies safe stage GDD and BP timing proposals sequentially', async () => {
    const onComplete = vi.fn();
    const onError = vi.fn();

    await useCase.execute({
      planId: PLAN_ID,
      stageGddProposals: [stageGdd()],
      blueprintTimingProposals: [bpTiming()],
      onComplete,
      onError
    });

    expect(cropStageGateway.updateThermalRequirement).toHaveBeenCalled();
    expect(setupProposalGateway.apply).toHaveBeenCalled();
    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, stageGddProposalProgressKey(1, 2))
    ).toBe('confirmed');
    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, bpTimingProposalProgressKey(3, 'general'))
    ).toBe('confirmed');
    expect(onComplete).toHaveBeenCalledWith({ appliedCount: 2, failedCount: 0 });
    expect(onError).not.toHaveBeenCalled();
  });

  it('reports partial failure when a proposal apply fails', async () => {
    setupProposalGateway.apply.mockReturnValue(throwError(() => new Error('network')));
    const onComplete = vi.fn();
    const onError = vi.fn();

    await useCase.execute({
      planId: PLAN_ID,
      stageGddProposals: [stageGdd()],
      blueprintTimingProposals: [bpTiming()],
      onComplete,
      onError
    });

    expect(onError).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({ appliedCount: 1, failedCount: 1 })
    );
    expect(onComplete).not.toHaveBeenCalled();
  });
});
