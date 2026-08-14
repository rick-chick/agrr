import { describe, expect, it } from 'vitest';
import {
  buildWorkRowMiniClimateSummary,
  computeWorkRowMiniClimateDateRange
} from './work-row-mini-climate';

describe('computeWorkRowMiniClimateDateRange', () => {
  it('returns a 7-day inclusive window ending on today', () => {
    expect(computeWorkRowMiniClimateDateRange('2026-06-17')).toEqual({
      startDate: '2026-06-11',
      endDate: '2026-06-17'
    });
  });
});

describe('buildWorkRowMiniClimateSummary', () => {
  it('returns cumulative GDD at end date and daily weather rows in range', () => {
    const summary = buildWorkRowMiniClimateSummary(
      [
        { date: '2026-06-15', gdd: 10, cumulative_gdd: 120 },
        { date: '2026-06-17', gdd: 8, cumulative_gdd: 145.5 }
      ],
      [
        {
          date: '2026-06-15',
          temperature_max: 28,
          temperature_min: 18,
          temperature_mean: 23
        },
        {
          date: '2026-06-16',
          temperature_max: 30,
          temperature_min: 20,
          temperature_mean: 25
        }
      ],
      '2026-06-11',
      '2026-06-17'
    );

    expect(summary.cumulativeGdd).toBe(145.5);
    expect(summary.dailyWeather).toEqual([
      {
        date: '2026-06-15',
        temperatureMax: 28,
        temperatureMin: 18,
        temperatureMean: 23
      },
      {
        date: '2026-06-16',
        temperatureMax: 30,
        temperatureMin: 20,
        temperatureMean: 25
      }
    ]);
  });

  it('returns null cumulative GDD when no gdd data exists', () => {
    const summary = buildWorkRowMiniClimateSummary([], [], '2026-06-11', '2026-06-17');

    expect(summary.cumulativeGdd).toBeNull();
    expect(summary.dailyWeather).toEqual([]);
  });
});
