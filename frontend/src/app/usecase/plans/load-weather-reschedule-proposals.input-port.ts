import { LoadWeatherRescheduleProposalsInputDto } from './load-weather-reschedule-proposals.dtos';

export interface LoadWeatherRescheduleProposalsInputPort {
  execute(dto: LoadWeatherRescheduleProposalsInputDto): void;
}
