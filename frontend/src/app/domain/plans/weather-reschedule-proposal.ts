export type WeatherRescheduleTriggerType =
  | 'frost_forecast'
  | 'gdd_trajectory_delay'
  | 'forecast_sudden_change';

export interface WeatherRescheduleProposalTargetCultivation {
  crop_name?: string;
  field_name?: string;
  start_date?: string | null;
  completion_date?: string | null;
}

export interface WeatherRescheduleProposalRationale {
  field_cultivation_id?: number;
  task_schedule_item_id?: number | null;
  trigger_date?: string | null;
  forecast_t_min?: number | null;
  frost_threshold?: number | null;
  gdd_delta?: number | null;
  forecast_t_min_delta?: number | null;
  gdd_trajectory_delay_threshold?: number | null;
  target_cultivation?: WeatherRescheduleProposalTargetCultivation;
}

export interface WeatherRescheduleProposal {
  id: string;
  trigger_type: WeatherRescheduleTriggerType;
  severity: string;
  rationale: WeatherRescheduleProposalRationale;
  moves: unknown[];
}
