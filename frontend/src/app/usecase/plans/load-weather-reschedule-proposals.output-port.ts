import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import type { WeatherRescheduleProposal } from '../../domain/plans/weather-reschedule-proposal';

export interface WeatherRescheduleProposalsDataDto {
  proposals: WeatherRescheduleProposal[];
  loadGeneration: number;
}

export interface LoadWeatherRescheduleProposalsOutputPort {
  present(dto: WeatherRescheduleProposalsDataDto): void;
  onError(dto: ErrorDto): void;
}

export const LOAD_WEATHER_RESCHEDULE_PROPOSALS_OUTPUT_PORT =
  new InjectionToken<LoadWeatherRescheduleProposalsOutputPort>(
    'LOAD_WEATHER_RESCHEDULE_PROPOSALS_OUTPUT_PORT'
  );
