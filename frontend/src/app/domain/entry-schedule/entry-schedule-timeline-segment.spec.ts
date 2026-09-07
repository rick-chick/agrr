import { describe, expect, it } from 'vitest';
import { calendarYearJanDecBounds } from './entry-schedule-timeline-bounds';
import { segmentStyleForRange } from './entry-schedule-timeline-segment';

describe('segmentStyleForRange', () => {
  it('places a 2027 window inside 2027 jan-dec bounds instead of clamping to the track edge', () => {
    const ctx = calendarYearJanDecBounds(2027);
    const style = segmentStyleForRange('2027-04-17', '2027-06-03', ctx);

    expect(style['display']).toBeUndefined();
    expect(style['left']).not.toBe('100%');
    expect(Number.parseFloat(style['width']!)).toBeGreaterThan(1);
  });
});
