import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

export interface ApplyWeatherRescheduleProposalDataDto {
  planData: CultivationPlanData;
}

export interface ApplyWeatherRescheduleProposalOutputPort {
  present(dto: ApplyWeatherRescheduleProposalDataDto): void;
  onError(dto: ErrorDto): void;
}

export const APPLY_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT =
  new InjectionToken<ApplyWeatherRescheduleProposalOutputPort>(
    'APPLY_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT'
  );
