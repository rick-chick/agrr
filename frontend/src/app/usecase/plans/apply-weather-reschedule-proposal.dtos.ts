import type { WeatherRescheduleAdjustMove } from '../../domain/plans/weather-reschedule-proposal-preview';
import { CultivationPlanContextType } from '../../domain/plans/cultivation-plan-context-type';

export interface ApplyWeatherRescheduleProposalInputDto {
  planId: number;
  planType: CultivationPlanContextType;
  moves: WeatherRescheduleAdjustMove[];
}
