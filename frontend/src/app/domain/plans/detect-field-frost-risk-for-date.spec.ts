import { describe, expect, it } from 'vitest';

import type { FieldCultivationClimateData } from './field-cultivation-climate-data';
import { detectFieldFrostRiskForDate } from './detect-field-frost-risk-for-date';

function sampleClimate(
  overrides: Partial<FieldCultivationClimateData> = {}
): FieldCultivationClimateData {
  return {
    success: true,
    field_cultivation: {
      id: 1,
      field_name: 'North',
      crop_name: 'Tomato',
      start_date: '2026-03-01',
      completion_date: '2026-06-30'
    },
    farm: { id: 10, name: 'Farm', latitude: 35.0, longitude: 139.0 },
    crop_requirements: {
      base_temperature: 10,
      optimal_temperature_range: { min: 15, max: 28, low_stress: 5, high_stress: 32 }
    },
    weather_data: [
      { date: '2026-08-14', temperature_min: -1, temperature_mean: 4, temperature_max: 10 }
    ],
    gdd_data: [{ date: '2026-08-14', gdd: 2, cumulative_gdd: 200, temperature: 4 }],
    stages: [
      {
        name: 'Growth',
        order: 1,
        gdd_required: 100,
        cumulative_gdd_required: 100,
        frost_threshold: 0,
        low_stress_threshold: 5
      }
    ],
    ...overrides
  };
}

describe('detectFieldFrostRiskForDate', () => {
  it('returns true when today min temperature is below stage frost threshold', () => {
    expect(detectFieldFrostRiskForDate(sampleClimate(), '2026-08-14')).toBe(true);
  });

  it('returns false when min temperature is at or above frost threshold', () => {
    const climate = sampleClimate({
      weather_data: [
        { date: '2026-08-14', temperature_min: 0, temperature_mean: 6, temperature_max: 12 }
      ]
    });

    expect(detectFieldFrostRiskForDate(climate, '2026-08-14')).toBe(false);
  });

  it('returns false when weather data for the date is missing', () => {
    expect(detectFieldFrostRiskForDate(sampleClimate(), '2026-08-15')).toBe(false);
  });

  it('falls back to low_stress_threshold when frost_threshold is absent', () => {
    const climate = sampleClimate({
      stages: [
        {
          name: 'Growth',
          order: 1,
          gdd_required: 100,
          cumulative_gdd_required: 100,
          low_stress_threshold: 3
        }
      ],
      weather_data: [
        { date: '2026-08-14', temperature_min: 2, temperature_mean: 6, temperature_max: 12 }
      ]
    });

    expect(detectFieldFrostRiskForDate(climate, '2026-08-14')).toBe(true);
  });
});
