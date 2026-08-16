import type { PlanWorkTodayAttentionWeatherTrigger } from './build-plan-work-today-attention';
import type { WeatherRescheduleProposal } from './weather-reschedule-proposal';

export function mapWeatherProposalsToAttentionTriggers(
  proposals: WeatherRescheduleProposal[]
): PlanWorkTodayAttentionWeatherTrigger[] {
  return proposals.map(mapWeatherProposalToAttentionTrigger);
}

export function mapWeatherProposalToAttentionTrigger(
  proposal: WeatherRescheduleProposal
): PlanWorkTodayAttentionWeatherTrigger {
  const target = proposal.rationale.target_cultivation ?? {};
  const fieldName = target.field_name ?? '';
  const cropName = target.crop_name ?? '';

  switch (proposal.trigger_type) {
    case 'frost_forecast':
      return {
        proposalId: proposal.id,
        triggerType: proposal.trigger_type,
        fieldName,
        cropName,
        rationaleI18nKey: 'plans.work.today_attention.weather_rationale.frost_forecast',
        rationaleI18nParams: {
          tMin: proposal.rationale.forecast_t_min ?? 0,
          threshold: proposal.rationale.frost_threshold ?? 0
        }
      };
    case 'gdd_trajectory_delay':
      return {
        proposalId: proposal.id,
        triggerType: proposal.trigger_type,
        fieldName,
        cropName,
        rationaleI18nKey: 'plans.work.today_attention.weather_rationale.gdd_trajectory_delay',
        rationaleI18nParams: {
          delta: proposal.rationale.gdd_delta ?? 0,
          threshold: proposal.rationale.gdd_trajectory_delay_threshold ?? 0
        }
      };
    case 'forecast_sudden_change':
      return {
        proposalId: proposal.id,
        triggerType: proposal.trigger_type,
        fieldName,
        cropName,
        rationaleI18nKey: 'plans.work.today_attention.weather_rationale.forecast_sudden_change',
        rationaleI18nParams: {
          delta: proposal.rationale.forecast_t_min_delta ?? 0
        }
      };
  }
}
