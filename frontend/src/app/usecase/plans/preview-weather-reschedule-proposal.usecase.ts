import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import { PreviewWeatherRescheduleProposalInputDto } from './preview-weather-reschedule-proposal.dtos';
import { PreviewWeatherRescheduleProposalInputPort } from './preview-weather-reschedule-proposal.input-port';
import {
  PREVIEW_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT,
  PreviewWeatherRescheduleProposalOutputPort
} from './preview-weather-reschedule-proposal.output-port';

@Injectable()
export class PreviewWeatherRescheduleProposalUseCase
  implements PreviewWeatherRescheduleProposalInputPort
{
  constructor(
    @Inject(PREVIEW_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT)
    private readonly outputPort: PreviewWeatherRescheduleProposalOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: PreviewWeatherRescheduleProposalInputDto): void {
    this.planGateway.previewWeatherRescheduleProposal(dto.planId, dto.proposalId).subscribe({
      next: (preview) => this.outputPort.present({ preview }),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
