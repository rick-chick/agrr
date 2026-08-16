import type { WeatherRescheduleProposal } from './weather-reschedule-proposal';

export interface WeatherRescheduleProposalAllocationSnapshot {
  field_schedules: unknown[];
}

export interface WeatherRescheduleProposalPreview {
  proposal_id: string;
  proposal: WeatherRescheduleProposal;
  moves: WeatherRescheduleAdjustMove[];
  before: WeatherRescheduleProposalAllocationSnapshot;
  after: WeatherRescheduleProposalAllocationSnapshot;
}

export interface WeatherRescheduleAdjustMove {
  allocation_id: number;
  action: 'move';
  to_field_id: number;
  to_start_date: string;
}

export interface WeatherRescheduleGanttOverlayBar {
  cultivationId: number;
  cropName: string;
  fieldName: string;
  startDate: string;
  completionDate: string;
}
