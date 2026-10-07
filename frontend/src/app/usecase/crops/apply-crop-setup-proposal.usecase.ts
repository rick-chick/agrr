import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  CROP_SETUP_PROPOSAL_GATEWAY,
  CropSetupProposalGateway
} from './crop-setup-proposal-gateway';
import {
  APPLY_CROP_SETUP_PROPOSAL_OUTPUT_PORT,
  ApplyCropSetupProposalInputDto,
  ApplyCropSetupProposalInputPort,
  ApplyCropSetupProposalOutputPort
} from './crop-setup-proposal.ports';

@Injectable()
export class ApplyCropSetupProposalUseCase implements ApplyCropSetupProposalInputPort {
  constructor(
    @Inject(APPLY_CROP_SETUP_PROPOSAL_OUTPUT_PORT)
    private readonly outputPort: ApplyCropSetupProposalOutputPort,
    @Inject(CROP_SETUP_PROPOSAL_GATEWAY) private readonly gateway: CropSetupProposalGateway
  ) {}

  execute(dto: ApplyCropSetupProposalInputDto): void {
    this.outputPort.onApplyStarted();
    this.gateway.apply(dto.cropId, dto.proposal).subscribe({
      next: (response) => {
        this.outputPort.onApplySuccess(response);
        if (response.valid === true) {
          dto.onSuccess?.();
        }
      },
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
