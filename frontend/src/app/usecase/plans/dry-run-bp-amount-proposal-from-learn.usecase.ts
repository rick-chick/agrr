import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import type { CropSetupProposalBody } from '../../domain/crops/crop-setup-proposal';
import {
  CROP_SETUP_PROPOSAL_GATEWAY,
  CropSetupProposalGateway
} from '../crops/crop-setup-proposal-gateway';

export interface DryRunBpAmountProposalFromLearnInputDto {
  cropId: number;
  proposal: CropSetupProposalBody;
  onSuccess?: (previewJson: string) => void;
  onError?: (message: string) => void;
}

@Injectable()
export class DryRunBpAmountProposalFromLearnUseCase {
  constructor(
    @Inject(CROP_SETUP_PROPOSAL_GATEWAY) private readonly gateway: CropSetupProposalGateway
  ) {}

  execute(dto: DryRunBpAmountProposalFromLearnInputDto): void {
    this.gateway.dryRun(dto.cropId, dto.proposal).subscribe({
      next: (response) => {
        if (!response.valid || !response.normalized) {
          dto.onError?.('crops.setup_proposal_import.apply_failed');
          return;
        }
        dto.onSuccess?.(JSON.stringify(response.normalized, null, 2));
      },
      error: (err: unknown) => dto.onError?.(apiErrorI18nKey(err))
    });
  }
}
