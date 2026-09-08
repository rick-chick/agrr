import { describe, expect, it } from 'vitest';
import { calendarYearJanDecBounds } from './entry-schedule-timeline-bounds';
import { segmentStyleForRange, segmentStylesForRange } from './entry-schedule-timeline-segment';

describe('segmentStyleForRange', () => {
  it('places a 2027 window inside 2027 jan-dec bounds instead of clamping to the track edge', () => {
    const ctx = calendarYearJanDecBounds(2027);
    const style = segmentStyleForRange('2027-04-17', '2027-06-03', ctx);

    expect(style['display']).toBeUndefined();
    expect(style['left']).not.toBe('100%');
    expect(Number.parseFloat(style['width']!)).toBeGreaterThan(1);
  });
});

describe('segmentStylesForRange', () => {
  it('splits a cross-year seasonal window into oct-dec and jan-jun segments on a jan-dec axis', () => {
    const ctx = calendarYearJanDecBounds(2026);
    const styles = segmentStylesForRange('2026-10-10', '2027-06-30', ctx);

    expect(styles).toHaveLength(2);
    expect(Number.parseFloat(styles[0]['left']!)).toBeGreaterThan(70);
    expect(Number.parseFloat(styles[0]['width']!)).toBeGreaterThan(10);
    expect(Number.parseFloat(styles[1]['left']!)).toBeLessThan(5);
    expect(Number.parseFloat(styles[1]['width']!)).toBeGreaterThan(40);
    expect(Number.parseFloat(styles[1]['left']!) + Number.parseFloat(styles[1]['width']!)).toBeLessThan(55);
  });

  it('returns a single segment for a same-calendar-year window', () => {
    const ctx = calendarYearJanDecBounds(2027);
    const styles = segmentStylesForRange('2027-04-17', '2027-06-03', ctx);

    expect(styles).toHaveLength(1);
    expect(styles[0]['display']).toBeUndefined();
  });
});
