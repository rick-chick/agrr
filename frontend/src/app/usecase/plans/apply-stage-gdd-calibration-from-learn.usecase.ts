import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  markLearnProposalConfirmed,
  stageGddProposalProgressKey
} from '../../domain/plans/learn-proposal-application-progress';
import { CROP_STAGE_GATEWAY, CropStageGateway } from '../crops/crop-stage-gateway';
import { upsertThermalRequirement } from '../crops/crop-stage-requirement-gateway-ops';

export interface ApplyStageGddCalibrationFromLearnInputDto {
  planId: number;
  cropId: number;
  stageId: number;
  proposedRequiredGdd: number;
  onSuccess?: () => void;
  onError?: (message: string) => void;
}

@Injectable()
export class ApplyStageGddCalibrationFromLearnUseCase {
  constructor(@Inject(CROP_STAGE_GATEWAY) private readonly cropStageGateway: CropStageGateway) {}

  execute(dto: ApplyStageGddCalibrationFromLearnInputDto): void {
    upsertThermalRequirement(this.cropStageGateway, dto.cropId, dto.stageId, {
      required_gdd: dto.proposedRequiredGdd
    }).subscribe({
      next: () => {
        markLearnProposalConfirmed(
          dto.planId,
          stageGddProposalProgressKey(dto.cropId, dto.stageId)
        );
        dto.onSuccess?.();
      },
      error: (err: unknown) => dto.onError?.(apiErrorI18nKey(err))
    });
  }
}
