import { describe, it, expect } from 'vitest';
import {
  computeGanttBarParams,
  daysBetween,
  ganttCropFillColor,
  ganttCropStrokeColor,
  normalizePlanBounds
} from './gantt-chart-layout';

describe('gantt-chart-layout', () => {
  it('normalizes inverted plan bounds', () => {
    const start = new Date('2026-12-31');
    const end = new Date('2026-01-01');
    const { start: normalizedStart, end: normalizedEnd } = normalizePlanBounds(start, end);
    expect(normalizedStart.getTime()).toBe(end.getTime());
    expect(normalizedEnd.getTime()).toBe(start.getTime());
  });

  it('computes bar position within the visible range', () => {
    const params = computeGanttBarParams({
      cultivationStart: new Date('2026-02-01'),
      cultivationEnd: new Date('2026-02-10'),
      visibleStart: new Date('2026-01-01'),
      visibleEnd: new Date('2026-03-31'),
      marginLeft: 80,
      chartWidth: 720
    });

    expect(params).not.toBeNull();
    expect(params!.x).toBeGreaterThan(80);
    expect(params!.width).toBeGreaterThan(0);
  });

  it('returns null when cultivation is outside the visible range', () => {
    const params = computeGanttBarParams({
      cultivationStart: new Date('2026-06-01'),
      cultivationEnd: new Date('2026-06-30'),
      visibleStart: new Date('2026-01-01'),
      visibleEnd: new Date('2026-03-31'),
      marginLeft: 80,
      chartWidth: 720
    });

    expect(params).toBeNull();
  });

  it('assigns stable crop colors from the crop name', () => {
    expect(ganttCropFillColor('Rice')).toBe(ganttCropFillColor('Rice'));
    expect(ganttCropStrokeColor('Rice')).toBe(ganttCropStrokeColor('Rice'));
    expect(ganttCropFillColor('Rice')).not.toBe(ganttCropFillColor('Wheat'));
  });

  it('counts whole days between dates', () => {
    expect(daysBetween(new Date('2026-01-01'), new Date('2026-01-11'))).toBe(10);
  });
});
