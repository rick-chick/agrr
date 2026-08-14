import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { BLUEPRINT_TIMING_PATCH_INTENT } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import { clearLearnProposalApplicationProgressCache } from '../../domain/plans/learn-proposal-application-progress';
import { ApplyBpTimingProposalFromLearnUseCase } from './apply-bp-timing-proposal-from-learn.usecase';
import { ApplyStageGddCalibrationFromLearnUseCase } from './apply-stage-gdd-calibration-from-learn.usecase';
import { BulkApplySafeLearnProposalsUseCase } from './bulk-apply-safe-learn-proposals.usecase';

describe('BulkApplySafeLearnProposalsUseCase', () => {
  let stageGddApply: { execute: ReturnType<typeof vi.fn> };
  let bpTimingApply: { execute: ReturnType<typeof vi.fn> };
  let useCase: BulkApplySafeLearnProposalsUseCase;

  beforeEach(() => {
    clearLearnProposalApplicationProgressCache();
    stageGddApply = {
      execute: vi.fn(({ onSuccess }: { onSuccess?: () => void }) => onSuccess?.())
    };
    bpTimingApply = {
      execute: vi.fn(({ onSuccess }: { onSuccess?: () => void }) => onSuccess?.())
    };

    TestBed.configureTestingModule({
      providers: [
        BulkApplySafeLearnProposalsUseCase,
        { provide: ApplyStageGddCalibrationFromLearnUseCase, useValue: stageGddApply },
        { provide: ApplyBpTimingProposalFromLearnUseCase, useValue: bpTimingApply }
      ]
    });
    useCase = TestBed.inject(BulkApplySafeLearnProposalsUseCase);
  });

  it('applies all safe proposals and reports success count', () => {
    const onSuccess = vi.fn();
    const onProgress = vi.fn();

    useCase.execute({
      planId: 7,
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
          averageGddDelta: 50,
          recordedItemCount: 2,
          currentRequiredGdd: 200,
          proposedRequiredGdd: 250
        }
      ],
      blueprintTimingProposals: [
        {
          cropId: 1,
          cropName: 'Tomato',
          category: 'general',
          averageDeltaDays: 2,
          averageGddDelta: 5,
          recordedItemCount: 3,
          affectedBlueprintCount: 1,
          proposalBody: {
            intent: BLUEPRINT_TIMING_PATCH_INTENT,
            stages: [],
            agricultural_tasks: [],
            task_schedule_blueprints: [{ blueprint_id: 10, gdd_trigger: 120 }]
          }
        }
      ],
      onProgress,
      onSuccess
    });

    expect(stageGddApply.execute).toHaveBeenCalledTimes(1);
    expect(bpTimingApply.execute).toHaveBeenCalledTimes(1);
    expect(onProgress).toHaveBeenCalledWith({ applied: 1, total: 2 });
    expect(onProgress).toHaveBeenCalledWith({ applied: 2, total: 2 });
    expect(onSuccess).toHaveBeenCalledWith({ appliedCount: 2, totalSafeCount: 2 });
  });

  it('calls onError when any apply fails', () => {
    stageGddApply.execute = vi.fn(({ onError }: { onError?: (message: string) => void }) =>
      onError?.('errors.generic')
    );
    const onError = vi.fn();

    useCase.execute({
      planId: 7,
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
      onError
    });

    expect(onError).toHaveBeenCalledWith('errors.generic');
  });

  it('succeeds immediately when no safe proposals exist', () => {
    const onSuccess = vi.fn();
    useCase.execute({
      planId: 7,
      stageGddProposals: [],
      blueprintTimingProposals: [],
      onSuccess
    });
    expect(onSuccess).toHaveBeenCalledWith({ appliedCount: 0, totalSafeCount: 0 });
  });
});
