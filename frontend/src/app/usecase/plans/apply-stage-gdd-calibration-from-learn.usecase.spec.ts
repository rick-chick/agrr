import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import {
  clearLearnProposalApplicationProgressCache,
  readLearnPostMasterPayload,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from '../../domain/plans/learn-proposal-application-progress';
import { CROP_STAGE_GATEWAY } from '../crops/crop-stage-gateway';
import { ApplyStageGddCalibrationFromLearnUseCase } from './apply-stage-gdd-calibration-from-learn.usecase';

describe('ApplyStageGddCalibrationFromLearnUseCase', () => {
  const PLAN_ID = 7;
  let useCase: ApplyStageGddCalibrationFromLearnUseCase;
  let gateway: {
    getThermalRequirement: ReturnType<typeof vi.fn>;
    updateThermalRequirement: ReturnType<typeof vi.fn>;
    createThermalRequirement: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
    gateway = {
      getThermalRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 2, required_gdd: 100 })),
      updateThermalRequirement: vi.fn(() => of({ id: 1, crop_stage_id: 2, required_gdd: 150 })),
      createThermalRequirement: vi.fn()
    };

    TestBed.configureTestingModule({
      providers: [
        ApplyStageGddCalibrationFromLearnUseCase,
        { provide: CROP_STAGE_GATEWAY, useValue: gateway }
      ]
    });
    useCase = TestBed.inject(ApplyStageGddCalibrationFromLearnUseCase);
  });

  it('updates thermal requirement and marks proposal confirmed on success', () => {
    const onSuccess = vi.fn();
    const onError = vi.fn();
    useCase.execute({
      planId: PLAN_ID,
      cropId: 1,
      cropName: 'Crop1',
      stageId: 2,
      stageName: 'Stage1',
      proposedRequiredGdd: 150,
      onSuccess,
      onError
    });

    expect(gateway.updateThermalRequirement).toHaveBeenCalledWith(1, 2, { required_gdd: 150 });
    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, stageGddProposalProgressKey(1, 2))
    ).toBe('confirmed');
    expect(readLearnPostMasterPayload(PLAN_ID)).toEqual({
      kind: 'stage_gdd',
      cropId: 1,
      cropName: 'Crop1',
      stageId: 2,
      stageName: 'Stage1',
      appliedRequiredGdd: 150
    });
    expect(onSuccess).toHaveBeenCalled();
    expect(onError).not.toHaveBeenCalled();
  });

  it('creates thermal requirement when none exists', () => {
    gateway.getThermalRequirement.mockReturnValue(of(null));
    gateway.createThermalRequirement.mockReturnValue(
      of({ id: 2, crop_stage_id: 2, required_gdd: 150 })
    );
    const onSuccess = vi.fn();
    const onError = vi.fn();

    useCase.execute({
      planId: PLAN_ID,
      cropId: 1,
      cropName: 'Crop1',
      stageId: 2,
      stageName: 'Stage1',
      proposedRequiredGdd: 150,
      onSuccess,
      onError
    });

    expect(gateway.createThermalRequirement).toHaveBeenCalledWith(1, 2, { required_gdd: 150 });
    expect(onSuccess).toHaveBeenCalled();
  });

  it('notifies onError when gateway fails', () => {
    gateway.updateThermalRequirement.mockReturnValue(throwError(() => new Error('network')));
    const onSuccess = vi.fn();
    const onError = vi.fn();

    useCase.execute({
      planId: PLAN_ID,
      cropId: 1,
      cropName: 'Crop1',
      stageId: 2,
      stageName: 'Stage1',
      proposedRequiredGdd: 150,
      onSuccess,
      onError
    });

    expect(onError).toHaveBeenCalled();
    expect(onSuccess).not.toHaveBeenCalled();
    expect(
      resolveLearnProposalApplicationStatus(PLAN_ID, stageGddProposalProgressKey(1, 2))
    ).toBe('not_started');
  });
});
