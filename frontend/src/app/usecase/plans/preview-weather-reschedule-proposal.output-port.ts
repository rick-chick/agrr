import { InjectionToken } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import type { WeatherRescheduleProposalPreview } from '../../domain/plans/weather-reschedule-proposal-preview';

export interface PreviewWeatherRescheduleProposalDataDto {
  preview: WeatherRescheduleProposalPreview;
}

export interface PreviewWeatherRescheduleProposalOutputPort {
  present(dto: PreviewWeatherRescheduleProposalDataDto): void;
  onError(dto: ErrorDto): void;
}

export const PREVIEW_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT =
  new InjectionToken<PreviewWeatherRescheduleProposalOutputPort>(
    'PREVIEW_WEATHER_RESCHEDULE_PROPOSAL_OUTPUT_PORT'
  );
