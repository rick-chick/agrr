import { describe, expect, it } from 'vitest';
import { seasonalWrapsCalendarYear } from './entry-schedule-seasonal-wrap';

describe('seasonalWrapsCalendarYear', () => {
  it('returns true for autumn-spring windows that cross calendar years', () => {
    expect(seasonalWrapsCalendarYear('2026-10-10', '2027-06-30')).toBe(true);
  });

  it('returns false when start and end share the same calendar year', () => {
    expect(seasonalWrapsCalendarYear('2027-04-17', '2027-06-03')).toBe(false);
  });

  it('returns false when end year is not after start year', () => {
    expect(seasonalWrapsCalendarYear('2027-06-30', '2026-10-10')).toBe(false);
    expect(seasonalWrapsCalendarYear('2026-10-10', '2026-06-30')).toBe(false);
  });

  it('returns false when month-day order does not indicate wrap within the span', () => {
    expect(seasonalWrapsCalendarYear('2026-03-01', '2027-08-31')).toBe(false);
  });

  it('returns false for invalid or non-finite year fragments', () => {
    expect(seasonalWrapsCalendarYear('abcd-10-10', '2027-06-30')).toBe(false);
    expect(seasonalWrapsCalendarYear('2026-10-10', 'zzzz-06-30')).toBe(false);
  });
});
