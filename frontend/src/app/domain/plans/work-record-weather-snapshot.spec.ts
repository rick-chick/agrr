import { describe, expect, it } from 'vitest';

import { workRecordWeatherSnapshotSummary } from './work-record-weather-snapshot';

describe('workRecordWeatherSnapshotSummary', () => {
  it('returns temperature summary when snapshot has weather data', () => {
    expect(
      workRecordWeatherSnapshotSummary({
        date: '2026-06-12',
        temperature_max: 28,
        temperature_min: 18,
        temperature_mean: 23
      })
    ).toEqual({
      max: 28,
      min: 18,
      mean: 23
    });
  });

  it('returns null when snapshot is missing or empty', () => {
    expect(workRecordWeatherSnapshotSummary(null)).toBeNull();
    expect(workRecordWeatherSnapshotSummary(undefined)).toBeNull();
    expect(workRecordWeatherSnapshotSummary({ date: '' })).toBeNull();
  });
});
