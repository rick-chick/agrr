import { describe, it, expect } from 'vitest';
import {
  addMonths,
  buildGanttFieldGroups,
  buildGanttTimeAxisSegments,
  computeCultivationDatesAfterMove,
  computeGanttBarDragStartDate,
  computeGanttBarParams,
  computeGanttTargetFieldIndex,
  computeGanttVisibleRangeEnd,
  daysBetween,
  determineGanttTimeScale,
  formatGanttVisibleRangeLabel,
  ganttCropFillColor,
  ganttCropStrokeColor,
  GanttTimeUnit,
  normalizePlanBounds,
  shouldCommitGanttDragMove,
  shouldReinitializeGanttVisibleRange
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

  it('groups cultivations by field id in stable field order', () => {
    const groups = buildGanttFieldGroups(
      [
        { id: 2, name: 'B' },
        { id: 1, name: 'A' }
      ],
      [
        { id: 10, field_id: 2, field_name: 'B' } as never,
        { id: 11, field_id: 1, field_name: 'A' } as never
      ]
    );
    expect(groups.map((g) => g.fieldId)).toEqual([1, 2]);
    expect(groups[0].cultivations).toHaveLength(1);
    expect(groups[1].cultivations[0].id).toBe(10);
  });

  it('builds time axis segments for a month-scale range', () => {
    const scale = determineGanttTimeScale(
      new Date('2026-01-01'),
      new Date('2026-06-30'),
      900
    );
    const segments = buildGanttTimeAxisSegments({
      visibleStart: new Date('2026-01-01'),
      visibleEnd: new Date('2026-06-30'),
      marginLeft: 80,
      chartWidth: 720,
      timeScale: scale,
      labelSuffixes: { day: '日', month: '月', quarter: 'Q' }
    });
    expect(segments.length).toBeGreaterThan(0);
    expect(segments[0].showYear).toBe(true);
    expect(segments[0].width).toBeGreaterThan(0);
  });

  it('formats visible range label', () => {
    expect(
      formatGanttVisibleRangeLabel(new Date('2026-01-15'), new Date('2026-12-20'))
    ).toBe('2026/01～2026/12');
  });

  it('computes visible range end from start', () => {
    const end = computeGanttVisibleRangeEnd(new Date('2026-01-01'), 24);
    expect(end.getFullYear()).toBe(2028);
    expect(end.getMonth()).toBe(0);
  });

  it('detects when visible range should reset after plan change', () => {
    const planStart = new Date('2026-01-01').getTime();
    const planEnd = new Date('2026-12-31').getTime();
    expect(
      shouldReinitializeGanttVisibleRange({
        planStartTime: planStart,
        planEndTime: planEnd,
        lastPlanStartTime: new Date('2025-01-01').getTime(),
        lastPlanEndTime: planEnd,
        visibleStart: new Date('2027-01-01'),
        visibleEnd: new Date('2027-06-01')
      })
    ).toBe(true);
    expect(
      shouldReinitializeGanttVisibleRange({
        planStartTime: planStart,
        planEndTime: planEnd,
        lastPlanStartTime: planStart,
        lastPlanEndTime: planEnd,
        visibleStart: new Date('2026-02-01'),
        visibleEnd: new Date('2026-08-01')
      })
    ).toBe(false);
  });

  it('maps bar x to drag start date', () => {
    const { daysFromStart, startDate } = computeGanttBarDragStartDate({
      barX: 80,
      marginLeft: 80,
      chartWidth: 720,
      displayStart: new Date('2026-01-01'),
      displayEnd: new Date('2026-03-31')
    });
    expect(daysFromStart).toBe(0);
    expect(startDate.toISOString().slice(0, 10)).toBe('2026-01-01');
  });

  it('clamps target field index when dragging across rows', () => {
    expect(
      computeGanttTargetFieldIndex({
        originalFieldIndex: 0,
        deltaY: 500,
        rowHeight: 68,
        fieldCount: 2
      })
    ).toBe(1);
  });

  it('commits drag when field changes or day offset exceeds threshold', () => {
    expect(
      shouldCommitGanttDragMove({
        originalFieldName: 'A',
        newFieldName: 'B',
        daysFromStart: 0
      })
    ).toBe(true);
    expect(
      shouldCommitGanttDragMove({
        originalFieldName: 'A',
        newFieldName: 'A',
        daysFromStart: 3
      })
    ).toBe(true);
    expect(
      shouldCommitGanttDragMove({
        originalFieldName: 'A',
        newFieldName: 'A',
        daysFromStart: 1
      })
    ).toBe(false);
  });

  it('preserves cultivation duration after move', () => {
    const dates = computeCultivationDatesAfterMove({
      oldStartDate: new Date('2026-02-01'),
      oldCompletionDate: new Date('2026-02-11'),
      newStartDate: new Date('2026-03-01')
    });
    expect(dates.startDate).toBe('2026-03-01');
    expect(dates.completionDate).toBe('2026-03-11');
  });

  it('adds months to a date', () => {
    const result = addMonths(new Date('2026-01-15'), 2);
    expect(result.getMonth()).toBe(2);
  });
});
