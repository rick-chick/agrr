import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import type { CropSetupProposalBody } from '../../domain/crops/crop-setup-proposal';
import {
  bpAmountProposalProgressKey,
  markLearnProposalConfirmed
} from '../../domain/plans/learn-proposal-application-progress';
import {
  CROP_SETUP_PROPOSAL_GATEWAY,
  CropSetupProposalGateway
} from '../crops/crop-setup-proposal-gateway';

export interface ApplyBpAmountProposalFromLearnInputDto {
  planId: number;
  cropId: number;
  category: string;
  taskType: string;
  stageOrder: number | null;
  proposal: CropSetupProposalBody;
  onSuccess?: () => void;
  onError?: (message: string) => void;
}

@Injectable()
export class ApplyBpAmountProposalFromLearnUseCase {
  constructor(
    @Inject(CROP_SETUP_PROPOSAL_GATEWAY) private readonly gateway: CropSetupProposalGateway
  ) {}

  execute(dto: ApplyBpAmountProposalFromLearnInputDto): void {
    this.gateway.apply(dto.cropId, dto.proposal).subscribe({
      next: (response) => {
        if (response.valid !== true) {
          dto.onError?.('crops.setup_proposal_import.apply_failed');
          return;
        }
        markLearnProposalConfirmed(
          dto.planId,
          bpAmountProposalProgressKey(
            dto.cropId,
            dto.category,
            dto.taskType,
            dto.stageOrder
          )
        );
        dto.onSuccess?.();
      },
      error: (err: unknown) => dto.onError?.(apiErrorI18nKey(err))
    });
  }
}
