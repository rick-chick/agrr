import { PreviewWeatherRescheduleProposalInputDto } from './preview-weather-reschedule-proposal.dtos';

export interface PreviewWeatherRescheduleProposalInputPort {
  execute(dto: PreviewWeatherRescheduleProposalInputDto): void;
}
