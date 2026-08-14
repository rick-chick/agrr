import { describe, expect, it } from 'vitest';
import { climatePreviewGddDelta, snapshotClimateForDate } from './work-record-climate-snapshot';

describe('snapshotClimateForDate', () => {
  it('extracts gdd and weather for the actual date', () => {
    const snapshot = snapshotClimateForDate(
      [
        { date: '2026-06-10', gdd: 10, cumulative_gdd: 120.5 },
        { date: '2026-06-12', gdd: 12, cumulative_gdd: 145.25 }
      ],
      [
        {
          date: '2026-06-10',
          temperature_max: 28,
          temperature_min: 18,
          temperature_mean: 23
        },
        {
          date: '2026-06-12',
          temperature_max: 30,
          temperature_min: 20,
          temperature_mean: 25
        }
      ],
      '2026-06-12'
    );

    expect(snapshot.gddAtActual).toBe(145.25);
    expect(snapshot.weatherSnapshot).toEqual({
      date: '2026-06-12',
      temperature_max: 30,
      temperature_min: 20,
      temperature_mean: 25
    });
  });

  it('uses last gdd on or before actual date when exact day is missing', () => {
    const snapshot = snapshotClimateForDate(
      [
        { date: '2026-06-10', gdd: 10, cumulative_gdd: 100 },
        { date: '2026-06-11', gdd: 10, cumulative_gdd: 110 }
      ],
      [],
      '2026-06-12'
    );

    expect(snapshot.gddAtActual).toBe(110);
    expect(snapshot.weatherSnapshot).toBeNull();
  });
});

describe('climatePreviewGddDelta', () => {
  it('returns delta between cumulative and planned gdd', () => {
    expect(climatePreviewGddDelta(145.25, 100)).toBe(45.3);
  });

  it('returns null when planned gdd is unavailable', () => {
    expect(climatePreviewGddDelta(145.25, null)).toBeNull();
  });

  it('returns null when cumulative gdd is unavailable', () => {
    expect(climatePreviewGddDelta(null, 100)).toBeNull();
  });
});
