import { describe, expect, it } from 'vitest';

import { mapWeatherProposalToAttentionTrigger } from './map-weather-proposals-to-attention-triggers';
import type { WeatherRescheduleProposal } from './weather-reschedule-proposal';

function sampleProposal(
  overrides: Partial<WeatherRescheduleProposal> = {}
): WeatherRescheduleProposal {
  return {
    id: 'frost_forecast:100:42',
    trigger_type: 'frost_forecast',
    severity: 'high',
    rationale: {
      forecast_t_min: -2,
      frost_threshold: 0,
      target_cultivation: {
        field_name: '北圃場',
        crop_name: 'トマト'
      }
    },
    moves: [],
    ...overrides
  };
}

describe('mapWeatherProposalToAttentionTrigger', () => {
  it('maps frost forecast proposal to attention trigger with rationale params', () => {
    const trigger = mapWeatherProposalToAttentionTrigger(sampleProposal());

    expect(trigger.proposalId).toBe('frost_forecast:100:42');
    expect(trigger.triggerType).toBe('frost_forecast');
    expect(trigger.fieldName).toBe('北圃場');
    expect(trigger.cropName).toBe('トマト');
    expect(trigger.rationaleI18nKey).toBe(
      'plans.work.today_attention.weather_rationale.frost_forecast'
    );
    expect(trigger.rationaleI18nParams).toEqual({ tMin: -2, threshold: 0 });
  });

  it('maps gdd trajectory delay proposal', () => {
    const trigger = mapWeatherProposalToAttentionTrigger(
      sampleProposal({
        id: 'gdd_trajectory_delay:100:0',
        trigger_type: 'gdd_trajectory_delay',
        rationale: {
          gdd_delta: 25,
          gdd_trajectory_delay_threshold: 10,
          target_cultivation: { field_name: '南圃場', crop_name: 'キュウリ' }
        }
      })
    );

    expect(trigger.triggerType).toBe('gdd_trajectory_delay');
    expect(trigger.rationaleI18nKey).toBe(
      'plans.work.today_attention.weather_rationale.gdd_trajectory_delay'
    );
    expect(trigger.rationaleI18nParams).toEqual({ delta: 25, threshold: 10 });
  });

  it('maps forecast sudden change proposal', () => {
    const trigger = mapWeatherProposalToAttentionTrigger(
      sampleProposal({
        id: 'forecast_sudden_change:100:0',
        trigger_type: 'forecast_sudden_change',
        rationale: {
          forecast_t_min_delta: -6,
          target_cultivation: { field_name: '東圃場', crop_name: 'ナス' }
        }
      })
    );

    expect(trigger.triggerType).toBe('forecast_sudden_change');
    expect(trigger.rationaleI18nParams).toEqual({ delta: -6 });
  });
});
