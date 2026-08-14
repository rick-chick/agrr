import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  clearLearnProposalApplicationProgressCache,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from '../../domain/plans/learn-proposal-application-progress';
import { CROP_SETUP_PROPOSAL_GATEWAY } from '../crops/crop-setup-proposal-gateway';
import { CROP_STAGE_GATEWAY } from '../crops/crop-stage-gateway';
import { ApplyBpTimingProposalFromLearnUseCase } from './apply-bp-timing-proposal-from-learn.usecase';
import { ApplyStageGddCalibrationFromLearnUseCase } from './apply-stage-gdd-calibration-from-learn.usecase';
import { BulkApplySafeLearnProposalsUseCase } from './bulk-apply-safe-learn-proposals.usecase';

describe('BulkApplySafeLearnProposalsUseCase', () => {
  const PLAN_ID = 7;
  let useCase: BulkApplySafeLearnProposalsUseCase;
  let cropStageGateway: {
    getThermalRequirement: ReturnType<typeof vi.fn>;
    updateThermalRequirement: ReturnType<typeof vi.fn>;
    createThermalRequirement: ReturnType<typeof vi.fn>;
  };
  let setupProposalGateway: { apply: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    clearLearnProposalApplicationProgressCache();
    cropStageGateway = {
      getThermalRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 2, required_gdd: 100 })),
      updateThermalRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 2, required_gdd: 150 })),
      createThermalRequirement: vi.fn()
    };
    setupProposalGateway = {
      apply: vi.fn(() => of({ valid: true }))
    };

    TestBed.configureTestingModule({
      providers: [
        BulkApplySafeLearnProposalsUseCase,
        ApplyStageGddCalibrationFromLearnUseCase,
        ApplyBpTimingProposalFromLearnUseCase,
        { provide: CROP_STAGE_GATEWAY, useValue: cropStageGateway },
        { provide: CROP_SETUP_PROPOSAL_GATEWAY, useValue: setupProposalGateway }
      ]
    });
    useCase = TestBed.inject(BulkApplySafeLearnProposalsUseCase);
  });

  it('applies only safe not_started proposals and marks them confirmed', async () => {
    const onSuccess = vi.fn();
    const onError = vi.fn();

    useCase.execute({
      planId: PLAN_ID,
      stageGddProposals: [
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 2,
          stageOrder: 1,
          stageName: 'Vegetative',
          averageGddDelta: 5,
          recordedItemCount: 2,
          currentRequiredGdd: 100,
          proposedRequiredGdd: 105
        },
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 3,
          stageOrder: 2,
          stageName: 'Flowering',
          averageGddDelta: 20,
          recordedItemCount: 2,
          currentRequiredGdd: 200,
          proposedRequiredGdd: 220
        }
      ],
      blueprintTimingProposals: [
        {
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
          }
        }
      ],
      onSuccess,
      onError
    });

    await vi.waitFor(() => expect(onSuccess).toHaveBeenCalledWith(2));
    expect(onError).not.toHaveBeenCalled();
    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, stageGddProposalProgressKey(1, 2))
    ).toBe('confirmed');
    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, stageGddProposalProgressKey(1, 3))
    ).toBe('not_started');
    expect(setupProposalGateway.apply).toHaveBeenCalledTimes(1);
  });

  it('calls onError when a proposal apply fails', async () => {
    cropStageGateway.updateThermalRequirement.mockReturnValue(throwError(() => new Error('network')));
    const onSuccess = vi.fn();
    const onError = vi.fn();

    useCase.execute({
      planId: PLAN_ID,
      stageGddProposals: [
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 2,
          stageOrder: 1,
          stageName: 'Vegetative',
          averageGddDelta: 5,
          recordedItemCount: 2,
          currentRequiredGdd: 100,
          proposedRequiredGdd: 105
        }
      ],
      blueprintTimingProposals: [],
      onSuccess,
      onError
    });

    await vi.waitFor(() => expect(onError).toHaveBeenCalled());
    expect(onSuccess).not.toHaveBeenCalled();
  });
});
