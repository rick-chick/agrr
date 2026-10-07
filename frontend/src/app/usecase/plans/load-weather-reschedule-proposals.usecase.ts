import { Inject, Injectable } from '@angular/core';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import type { WeatherRescheduleProposal } from '../../domain/plans/weather-reschedule-proposal';
import { PLAN_GATEWAY, PlanGateway } from './plan-gateway';
import { LoadWeatherRescheduleProposalsInputDto } from './load-weather-reschedule-proposals.dtos';
import { LoadWeatherRescheduleProposalsInputPort } from './load-weather-reschedule-proposals.input-port';
import {
  LOAD_WEATHER_RESCHEDULE_PROPOSALS_OUTPUT_PORT,
  LoadWeatherRescheduleProposalsOutputPort
} from './load-weather-reschedule-proposals.output-port';

@Injectable()
export class LoadWeatherRescheduleProposalsUseCase
  implements LoadWeatherRescheduleProposalsInputPort
{
  constructor(
    @Inject(LOAD_WEATHER_RESCHEDULE_PROPOSALS_OUTPUT_PORT)
    private readonly outputPort: LoadWeatherRescheduleProposalsOutputPort,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(dto: LoadWeatherRescheduleProposalsInputDto): void {
    this.planGateway.getWeatherRescheduleProposals(dto.planId).subscribe({
      next: (proposals: WeatherRescheduleProposal[]) =>
        this.outputPort.present({ proposals, loadGeneration: dto.loadGeneration }),
      error: (err: unknown) => this.outputPort.onError({ message: apiErrorI18nKey(err) })
    });
  }
}
