import { ApplyWeatherRescheduleProposalInputDto } from './apply-weather-reschedule-proposal.dtos';

export interface ApplyWeatherRescheduleProposalInputPort {
  execute(dto: ApplyWeatherRescheduleProposalInputDto): void;
}
