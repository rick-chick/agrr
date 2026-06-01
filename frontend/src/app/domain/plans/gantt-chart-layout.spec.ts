import { describe, it, expect } from 'vitest';
import type { CultivationData } from './cultivation-plan-data';
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
  applyGanttCultivationMove,
  buildGanttAdjustMove,
  getGanttDragActivationThresholdPx,
  resolveGanttDragCommit,
  resolveGanttEndingTouchIndex,
  shouldIgnoreGanttPointerCancel,
  shouldActivateGanttDrag,
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

  it('uses higher drag activation threshold on mobile', () => {
    expect(getGanttDragActivationThresholdPx(false)).toBe(3);
    expect(getGanttDragActivationThresholdPx(true)).toBe(12);
    expect(shouldActivateGanttDrag(3, false)).toBe(false);
    expect(shouldActivateGanttDrag(4, false)).toBe(true);
    expect(shouldActivateGanttDrag(12, true)).toBe(false);
    expect(shouldActivateGanttDrag(13, true)).toBe(true);
    expect(shouldIgnoreGanttPointerCancel(true)).toBe(true);
    expect(shouldIgnoreGanttPointerCancel(false)).toBe(false);
  });

  it('resolveGanttEndingTouchIndex matches active pointer or single touch only', () => {
    expect(
      resolveGanttEndingTouchIndex({ changedTouchIds: [2], activePointerId: 2 })
    ).toBe(0);
    expect(
      resolveGanttEndingTouchIndex({ changedTouchIds: [1, 2], activePointerId: 2 })
    ).toBe(1);
    expect(
      resolveGanttEndingTouchIndex({ changedTouchIds: [1, 2], activePointerId: 9 })
    ).toBeNull();
    expect(
      resolveGanttEndingTouchIndex({ changedTouchIds: [4], activePointerId: null })
    ).toBe(0);
  });

  it('resolveGanttDragCommit detects position change for commit', () => {
    const layout = {
      marginLeft: 80,
      chartWidth: 720,
      rowHeight: 68,
      displayStart: new Date('2026-01-01'),
      displayEnd: new Date('2026-03-31')
    };
    const params = computeGanttBarParams({
      cultivationStart: new Date('2026-02-01'),
      cultivationEnd: new Date('2026-02-10'),
      visibleStart: layout.displayStart,
      visibleEnd: layout.displayEnd,
      marginLeft: layout.marginLeft,
      chartWidth: layout.chartWidth
    });
    expect(params).toBeTruthy();

    const unchanged = resolveGanttDragCommit({
      barX: params!.x,
      barY: 10,
      originalBarY: 10,
      originalBarX: params!.x,
      originalFieldIndex: 0,
      originalFieldName: 'Field A',
      fieldGroups: [{ fieldName: 'Field A' }],
      layout
    });
    expect(unchanged.shouldCommit).toBe(false);

    const moved = resolveGanttDragCommit({
      barX: params!.x + 40,
      barY: 10,
      originalBarY: 10,
      originalBarX: params!.x,
      originalFieldIndex: 0,
      originalFieldName: 'Field A',
      fieldGroups: [{ fieldName: 'Field A' }],
      layout
    });
    expect(moved.shouldCommit).toBe(true);
    expect(moved.daysOffsetDelta).not.toBe(0);
  });

  it('buildGanttAdjustMove formats ISO date only', () => {
    const move = buildGanttAdjustMove(9, 2, new Date('2026-03-15T12:00:00Z'));
    expect(move).toEqual({
      allocation_id: 9,
      action: 'move',
      to_field_id: 2,
      to_start_date: '2026-03-15'
    });
  });

  it('applyGanttCultivationMove updates cultivation dates and field', () => {
    const cultivation = {
      id: 1,
      field_id: 1,
      field_name: 'Field A',
      crop_name: 'Rice',
      start_date: '2026-02-01',
      completion_date: '2026-02-11'
    } as CultivationData;
    const fieldGroups = buildGanttFieldGroups(
      [{ id: 2, name: 'Field B' }],
      [cultivation]
    );
    applyGanttCultivationMove({
      cultivation,
      fieldGroups,
      newFieldName: 'Field B',
      newFieldIndex: 0,
      newStartDate: new Date('2026-03-01')
    });
    expect(cultivation.start_date).toBe('2026-03-01');
    expect(cultivation.completion_date).toBe('2026-03-11');
    expect(cultivation.field_name).toBe('Field B');
    expect(cultivation.field_id).toBe(2);
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
