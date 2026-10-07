import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import {
  CROP_SETUP_PROPOSAL_GATEWAY,
  CropSetupProposalGateway
} from './crop-setup-proposal-gateway';
import {
  DRY_RUN_CROP_SETUP_PROPOSAL_OUTPUT_PORT,
  DryRunCropSetupProposalInputDto,
  DryRunCropSetupProposalInputPort,
  DryRunCropSetupProposalOutputPort
} from './crop-setup-proposal.ports';

@Injectable()
export class DryRunCropSetupProposalUseCase implements DryRunCropSetupProposalInputPort {
  constructor(
    @Inject(DRY_RUN_CROP_SETUP_PROPOSAL_OUTPUT_PORT)
    private readonly outputPort: DryRunCropSetupProposalOutputPort,
    @Inject(CROP_SETUP_PROPOSAL_GATEWAY) private readonly gateway: CropSetupProposalGateway
  ) {}

  execute(dto: DryRunCropSetupProposalInputDto): void {
    this.outputPort.onDryRunStarted();
    this.gateway.dryRun(dto.cropId, dto.proposal).subscribe({
      next: (response) => this.outputPort.onDryRunSuccess(response),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
