import { describe, expect, it } from 'vitest';
import {
  calendarYearJanDecBounds,
  timelineBoundsFromSummaries,
} from './entry-schedule-timeline-bounds';

describe('timelineBoundsFromSummaries', () => {
  it('returns jan-dec bounds for the summary year when all dates share one calendar year', () => {
    const bounds = timelineBoundsFromSummaries([
      { start_date: '2027-04-17', end_date: '2027-06-03' },
      { start_date: '2027-04-17', end_date: '2027-06-03' },
    ]);

    expect(bounds).not.toBeNull();
    expect(bounds!.yearLabel).toBe('2027');
    expect(bounds!.min).toBe(calendarYearJanDecBounds(2027).min);
    expect(bounds!.max).toBe(calendarYearJanDecBounds(2027).max);
  });

  it('returns padded range bounds when summaries span multiple years without seasonal wrap', () => {
    const bounds = timelineBoundsFromSummaries([
      { start_date: '2026-03-01', end_date: '2027-08-31' },
    ]);

    expect(bounds).not.toBeNull();
    expect(bounds!.yearLabel).toBe('2026–2027');
    expect(bounds!.min).toBeLessThan(Date.parse('2026-03-01'));
    expect(bounds!.max).toBeGreaterThan(Date.parse('2027-08-31'));
  });

  it('returns jan-dec bounds for cross-year seasonal wrap windows', () => {
    const bounds = timelineBoundsFromSummaries([
      { start_date: '2026-10-10', end_date: '2027-06-30' },
    ]);

    expect(bounds).not.toBeNull();
    expect(bounds!.yearLabel).toBe('2026–2027');
    expect(bounds!.min).toBe(calendarYearJanDecBounds(2026).min);
    expect(bounds!.max).toBe(calendarYearJanDecBounds(2026).max);
  });

  it('returns null when no valid summaries are provided', () => {
    expect(timelineBoundsFromSummaries([null, undefined])).toBeNull();
  });

  it('ignores null summaries and uses valid date ranges', () => {
    const bounds = timelineBoundsFromSummaries([
      null,
      { start_date: '2027-04-17', end_date: '2027-06-03' },
      undefined,
    ]);

    expect(bounds).not.toBeNull();
    expect(bounds!.yearLabel).toBe('2027');
    expect(bounds!.min).toBe(calendarYearJanDecBounds(2027).min);
    expect(bounds!.max).toBe(calendarYearJanDecBounds(2027).max);
  });
});
