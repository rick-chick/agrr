import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import type { CropSetupProposalBody } from '../../domain/crops/crop-setup-proposal';
import {
  bpTimingProposalProgressKey,
  markLearnProposalConfirmed
} from '../../domain/plans/learn-proposal-application-progress';
import {
  CROP_SETUP_PROPOSAL_GATEWAY,
  CropSetupProposalGateway
} from '../crops/crop-setup-proposal-gateway';

export interface ApplyBpTimingProposalFromLearnInputDto {
  planId: number;
  cropId: number;
  category: string;
  proposal: CropSetupProposalBody;
  onSuccess?: () => void;
  onError?: (message: string) => void;
}

@Injectable()
export class ApplyBpTimingProposalFromLearnUseCase {
  constructor(
    @Inject(CROP_SETUP_PROPOSAL_GATEWAY) private readonly gateway: CropSetupProposalGateway
  ) {}

  execute(dto: ApplyBpTimingProposalFromLearnInputDto): void {
    this.gateway.apply(dto.cropId, dto.proposal).subscribe({
      next: (response) => {
        if (response.valid !== true) {
          dto.onError?.('crops.setup_proposal_import.apply_failed');
          return;
        }
        markLearnProposalConfirmed(
          dto.planId,
          bpTimingProposalProgressKey(dto.cropId, dto.category)
        );
        dto.onSuccess?.();
      },
      error: (err: unknown) => dto.onError?.(apiErrorI18nKey(err))
    });
  }
}
