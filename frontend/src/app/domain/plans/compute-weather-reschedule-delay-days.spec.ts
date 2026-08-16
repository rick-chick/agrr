import { describe, expect, it } from 'vitest';
import { computeWeatherRescheduleDelayDays } from './compute-weather-reschedule-delay-days';

describe('computeWeatherRescheduleDelayDays', () => {
  it('returns day delta between current start and proposed move date', () => {
    const delay = computeWeatherRescheduleDelayDays('2026-04-01', [
      {
        allocation_id: 1,
        action: 'move',
        to_field_id: 2,
        to_start_date: '2026-04-11'
      }
    ]);
    expect(delay).toBe(10);
  });

  it('returns null when no move action exists', () => {
    expect(computeWeatherRescheduleDelayDays('2026-04-01', [])).toBeNull();
  });
});
