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
  buildGanttVisibleRangeFromStart,
  computeGanttBarParamsForPlanView,
  formatGanttVisibleRangeLabel,
  ganttCropFillColor,
  ganttCropStrokeColor,
  normalizePlanBounds,
  applyGanttCultivationMove,
  buildGanttAdjustMove,
  getGanttDragActivationThresholdPx,
  getGanttMarginLeft,
  formatGanttFieldRowIndexLabel,
  getGanttFieldLabelCenterX,
  getGanttFieldLabelAnchorX,
  getGanttFieldDividerX,
  getGanttFieldLabelClipWidth,
  computeGanttBarLabelPosition,
  GANTT_FIELD_LABEL_CLIP_PADDING,
  GANTT_FIELD_LABEL_GAP,
  resolveGanttBarLabelPresentation,
  resolveGanttYearLabelPlacement,
  resolveGanttDragFieldContext,
  resolveGanttDragDrop,
  GANTT_MARGIN_LEFT_DESKTOP,
  GANTT_MARGIN_LEFT_MOBILE,
  resolveGanttDragCommit,
  pickGanttActiveTouchIndex,
  collectTouchIdentifiers,
  computeGanttPointerDragDistancePx,
  computeGanttChartHeight,
  shouldShowGanttTrashDropzone,
  resolveGanttMobileDragFieldContext,
  computeGanttDragPointerSvgOffset,
  computeGanttDragBarSvgPosition,
  resolveGanttEffectiveDisplayRange,
  buildGanttDragDropLayout,
  shouldIgnoreGanttPointerCancel,
  shouldActivateGanttDrag,
  shouldReinitializeGanttVisibleRange,
  parseGanttPlanBounds,
  buildGanttAddCropDisplayRange,
  isPointInsideClientRect,
  clampGanttChartWidth,
  formatIsoDateOnly,
  isGanttVisibleRangeWithinPlan,
  GANTT_MIN_CHART_WIDTH,
  GanttTimeUnit,
  getNextGanttTimeSegment,
  getGanttTimeLabel,
  shouldShowGanttYearOnAxis,
  computeGanttFieldRowHighlightY
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

  it('buildGanttVisibleRangeFromStart returns start, end, and label', () => {
    const range = buildGanttVisibleRangeFromStart(new Date('2026-03-01'));
    expect(range).not.toBeNull();
    expect(range!.startDate.toISOString().slice(0, 10)).toBe('2026-03-01');
    expect(range!.label).toBe('2026/03～2028/03');
  });

  it('buildGanttVisibleRangeFromStart returns null for invalid dates', () => {
    expect(buildGanttVisibleRangeFromStart(new Date('invalid'))).toBeNull();
  });

  it('computeGanttBarParamsForPlanView uses visible range when set', () => {
    const params = computeGanttBarParamsForPlanView({
      cultivationStart: '2026-02-01',
      cultivationEnd: '2026-02-28',
      planningStartDate: '2026-01-01',
      planningEndDate: '2026-12-31',
      visibleStart: new Date('2026-02-01'),
      visibleEnd: new Date('2026-05-31'),
      marginLeft: 80,
      chartWidth: 1000
    });
    expect(params).toEqual({ x: 80, width: expect.any(Number) });
    expect(params!.width).toBeGreaterThan(0);
  });

  it('formats visible range label', () => {
    expect(
      formatGanttVisibleRangeLabel(new Date('2026-01-15'), new Date('2026-12-20'))
    ).toBe('2026/01～2026/12');
  });

  it('computeGanttVisibleRangeEnd never returns a range end before the start', () => {
    const start = new Date('2026-01-31T00:00:00Z');
    const end = computeGanttVisibleRangeEnd(start, 0);
    expect(end.getTime()).toBeGreaterThanOrEqual(start.getTime());
  });

  it('resolveGanttDragDrop keeps the original field when no row groups exist', () => {
    const displayStart = new Date('2026-01-01');
    const displayEnd = new Date('2026-12-31');
    const resolved = resolveGanttDragDrop({
      barX: 120,
      barY: 200,
      originalBarY: 180,
      marginLeft: 80,
      chartWidth: 900,
      rowHeight: 68,
      displayStart,
      displayEnd,
      originalFieldIndex: 0,
      originalFieldName: 'North',
      fieldGroups: []
    });

    expect(resolved.newFieldIndex).toBe(0);
    expect(resolved.newFieldName).toBe('North');
    expect(resolved.daysFromStart).toBeGreaterThanOrEqual(0);
    expect(resolved.newStartDate.getTime()).toBeGreaterThanOrEqual(displayStart.getTime());
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
    expect(
      shouldReinitializeGanttVisibleRange({
        planStartTime: planStart,
        planEndTime: new Date('2027-12-31').getTime(),
        lastPlanStartTime: planStart,
        lastPlanEndTime: planEnd,
        visibleStart: new Date('2026-02-01'),
        visibleEnd: new Date('2026-08-01')
      })
    ).toBe(false);
  });

  it('computes chart height from row count and margins', () => {
    expect(
      computeGanttChartHeight({
        marginTop: 60,
        rowCount: 0,
        rowHeight: 68,
        marginBottom: 12
      })
    ).toBe(72);
    expect(
      computeGanttChartHeight({
        marginTop: 60,
        rowCount: 1,
        rowHeight: 68,
        marginBottom: 12
      })
    ).toBe(140);
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

  it('exposes desktop and mobile left margins', () => {
    expect(GANTT_MARGIN_LEFT_DESKTOP).toBe(80);
    expect(GANTT_MARGIN_LEFT_MOBILE).toBe(36);
    expect(getGanttMarginLeft(false)).toBe(80);
    expect(getGanttMarginLeft(true)).toBe(36);
  });

  it('formats field row index labels as 1-based strings', () => {
    expect(formatGanttFieldRowIndexLabel(0)).toBe('1');
    expect(formatGanttFieldRowIndexLabel(4)).toBe('5');
    expect(getGanttFieldLabelCenterX(80)).toBe(40);
    expect(getGanttFieldLabelCenterX(36)).toBe(18);
  });

  it('keeps desktop field label anchor left of the row divider with a fixed gap', () => {
    const marginLeft = GANTT_MARGIN_LEFT_DESKTOP;
    const dividerX = getGanttFieldDividerX(marginLeft);
    const anchorX = getGanttFieldLabelAnchorX(marginLeft);
    expect(dividerX).toBe(marginLeft - 10);
    expect(anchorX).toBe(dividerX - GANTT_FIELD_LABEL_GAP);
    expect(anchorX + GANTT_FIELD_LABEL_GAP).toBeLessThanOrEqual(dividerX);
  });

  it('keeps mobile field label anchor left of the row divider with a fixed gap', () => {
    const marginLeft = GANTT_MARGIN_LEFT_MOBILE;
    const dividerX = getGanttFieldDividerX(marginLeft);
    const anchorX = getGanttFieldLabelAnchorX(marginLeft);
    expect(anchorX + GANTT_FIELD_LABEL_GAP).toBeLessThanOrEqual(dividerX);
  });

  it('getGanttFieldLabelClipWidth ends before the row divider padding', () => {
    const desktopClip = getGanttFieldLabelClipWidth(GANTT_MARGIN_LEFT_DESKTOP);
    const mobileClip = getGanttFieldLabelClipWidth(GANTT_MARGIN_LEFT_MOBILE);
    expect(desktopClip).toBe(
      getGanttFieldDividerX(GANTT_MARGIN_LEFT_DESKTOP) - GANTT_FIELD_LABEL_CLIP_PADDING
    );
    expect(mobileClip).toBe(
      getGanttFieldDividerX(GANTT_MARGIN_LEFT_MOBILE) - GANTT_FIELD_LABEL_CLIP_PADDING
    );
    expect(desktopClip).toBe(66);
    expect(mobileClip).toBe(22);
  });

  it('computeGanttBarLabelPosition centers labels vertically and defers horizontal layout', () => {
    const narrow = computeGanttBarLabelPosition({
      barX: 120,
      barWidth: 48,
      labelReserve: 32,
      barY: 200,
      barHeight: 48
    });
    expect(narrow.y).toBe(200 + 48 / 2 + 5);
    expect(narrow.x).toBe(130);

    const wide = computeGanttBarLabelPosition({
      barX: 200,
      barWidth: 120,
      labelReserve: 32,
      barY: 100,
      barHeight: 40
    });
    expect(wide.y).toBe(125);
    expect(wide.x).toBe(200 + (120 - 32) / 2);
  });

  it('resolveGanttDragFieldContext returns row index and name or null', () => {
    const groups = [{ fieldName: 'A' }, { fieldName: 'B' }];
    expect(resolveGanttDragFieldContext({ targetFieldIndex: 1, fieldGroups: groups })).toEqual({
      rowIndex: 2,
      fieldName: 'B'
    });
    expect(resolveGanttDragFieldContext({ targetFieldIndex: -1, fieldGroups: groups })).toBeNull();
    expect(resolveGanttDragFieldContext({ targetFieldIndex: 2, fieldGroups: groups })).toBeNull();
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

  it('pickGanttActiveTouchIndex matches active pointer or single touch only', () => {
    expect(pickGanttActiveTouchIndex([2], 2)).toBe(0);
    expect(pickGanttActiveTouchIndex([1, 2], 2)).toBe(1);
    expect(pickGanttActiveTouchIndex([1, 2], 9)).toBeNull();
    expect(pickGanttActiveTouchIndex([4], null)).toBe(0);
  });

  it('collectTouchIdentifiers reads touch ids in order', () => {
    expect(collectTouchIdentifiers(2, (i) => (i === 0 ? 1 : 2))).toEqual([1, 2]);
    expect(collectTouchIdentifiers(1, () => undefined)).toEqual([]);
  });

  it('computeGanttPointerDragDistancePx uses euclidean distance', () => {
    expect(computeGanttPointerDragDistancePx(103, 104, 100, 100)).toBe(5);
  });

  it('shouldShowGanttTrashDropzone follows drag rules on mobile and desktop', () => {
    expect(
      shouldShowGanttTrashDropzone({
        isMobileLayout: false,
        isDragging: true,
        pointerDragDistance: 100
      })
    ).toBe(true);
    expect(
      shouldShowGanttTrashDropzone({
        isMobileLayout: false,
        isDragging: false,
        pointerDragDistance: 2
      })
    ).toBe(false);
    expect(
      shouldShowGanttTrashDropzone({
        isMobileLayout: false,
        isDragging: false,
        pointerDragDistance: 4
      })
    ).toBe(true);
    expect(
      shouldShowGanttTrashDropzone({
        isMobileLayout: true,
        isDragging: false,
        pointerDragDistance: 8
      })
    ).toBe(false);
    expect(
      shouldShowGanttTrashDropzone({
        isMobileLayout: true,
        isDragging: false,
        pointerDragDistance: 13
      })
    ).toBe(true);
    expect(
      shouldShowGanttTrashDropzone({
        isMobileLayout: true,
        isDragging: true,
        pointerDragDistance: 0
      })
    ).toBe(true);
  });

  it('resolveGanttMobileDragFieldContext hides same row and requires mobile drag', () => {
    const groups = [{ fieldName: 'A' }, { fieldName: 'B' }];
    expect(
      resolveGanttMobileDragFieldContext({
        isMobileLayout: false,
        isDragging: true,
        targetFieldIndex: 1,
        originalFieldIndex: 0,
        fieldGroups: groups
      })
    ).toBeNull();
    expect(
      resolveGanttMobileDragFieldContext({
        isMobileLayout: true,
        isDragging: true,
        targetFieldIndex: 0,
        originalFieldIndex: 0,
        fieldGroups: groups
      })
    ).toBeNull();
    expect(
      resolveGanttMobileDragFieldContext({
        isMobileLayout: true,
        isDragging: true,
        targetFieldIndex: 1,
        originalFieldIndex: 0,
        fieldGroups: groups
      })
    ).toEqual({ rowIndex: 2, fieldName: 'B' });
  });

  it('computeGanttDragPointerSvgOffset records svg grab offset', () => {
    expect(
      computeGanttDragPointerSvgOffset({
        pointerSvgX: 120,
        pointerSvgY: 50,
        originalBarX: 100,
        currentBarY: 10
      })
    ).toEqual({ x: 20, y: 40 });
  });

  it('computeGanttDragBarSvgPosition returns bar coords and row highlight', () => {
    const result = computeGanttDragBarSvgPosition({
      pointerSvgX: 150,
      pointerSvgY: 77,
      initialOffset: { x: 20, y: 40 },
      originalBarY: 10,
      originalFieldIndex: 0,
      rowHeight: 68,
      fieldCount: 2,
      headerHeight: 60
    });
    expect(result.barX).toBe(130);
    expect(result.barY).toBe(37);
    expect(result.targetFieldIndex).toBe(0);
    expect(result.rowHighlight).toEqual({ visible: false });

    const movedRow = computeGanttDragBarSvgPosition({
      pointerSvgX: 150,
      pointerSvgY: 200,
      initialOffset: { x: 20, y: 40 },
      originalBarY: 10,
      originalFieldIndex: 0,
      rowHeight: 68,
      fieldCount: 2,
      headerHeight: 60
    });
    expect(movedRow.targetFieldIndex).toBe(1);
    expect(movedRow.rowHighlight).toEqual({
      visible: true,
      y: 128,
      height: 68,
      opacity: 0.4
    });
  });

  it('resolveGanttEffectiveDisplayRange prefers drag snapshot then visible then plan', () => {
    const dragStart = new Date('2026-02-01');
    const dragEnd = new Date('2026-04-01');
    const visibleStart = new Date('2026-01-01');
    const planStart = new Date('2025-01-01');
    expect(
      resolveGanttEffectiveDisplayRange({
        dragStartDisplayStart: dragStart,
        dragStartDisplayEnd: dragEnd,
        visibleStart,
        visibleEnd: null,
        planStart,
        planEnd: null
      })
    ).toEqual({ start: dragStart, end: dragEnd });
  });

  it('buildGanttDragDropLayout copies chart layout fields', () => {
    const start = new Date('2026-01-01');
    const end = new Date('2026-03-31');
    expect(
      buildGanttDragDropLayout({
        marginLeft: 36,
        chartWidth: 700,
        rowHeight: 68,
        displayStart: start,
        displayEnd: end
      })
    ).toEqual({
      marginLeft: 36,
      chartWidth: 700,
      rowHeight: 68,
      displayStart: start,
      displayEnd: end
    });
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

  it('month shifts are not clamped to planning bounds', () => {
    const planEnd = new Date('2026-12-31');
    const shiftedBack = addMonths(new Date('2026-01-01'), -1);
    expect(shiftedBack.getFullYear()).toBe(2025);
    expect(shiftedBack.getMonth()).toBe(11);

    const shiftedForward = addMonths(shiftedBack, 36);
    expect(shiftedForward.getTime()).toBeGreaterThan(planEnd.getTime());
  });

  it('parseGanttPlanBounds returns null for invalid dates', () => {
    expect(parseGanttPlanBounds(undefined, '2026-12-31')).toEqual({ start: null, end: null });
    expect(parseGanttPlanBounds('invalid', '2026-12-31')).toEqual({ start: null, end: null });
  });

  it('parseGanttPlanBounds normalizes valid plan dates', () => {
    const bounds = parseGanttPlanBounds('2026-01-01', '2026-06-30');
    expect(bounds.start?.toISOString().slice(0, 10)).toBe('2026-01-01');
    expect(bounds.end?.toISOString().slice(0, 10)).toBe('2026-06-30');
  });

  it('buildGanttAddCropDisplayRange prefers visible range over plan bounds', () => {
    const range = buildGanttAddCropDisplayRange({
      visibleStart: new Date('2026-02-01'),
      visibleEnd: new Date('2026-05-01'),
      planStart: new Date('2026-01-01'),
      planEnd: new Date('2026-12-31')
    });
    expect(range).toEqual({ start: '2026-02-01', end: '2026-05-01' });
  });

  it('isPointInsideClientRect detects pointer within rect', () => {
    const rect = { left: 10, right: 20, top: 30, bottom: 40 };
    expect(isPointInsideClientRect(15, 35, rect)).toBe(true);
    expect(isPointInsideClientRect(5, 35, rect)).toBe(false);
  });

  it('resolveGanttYearLabelPlacement anchors the last axis year inside the chart right edge', () => {
    const chartAreaRightX = 1000;
    const last = resolveGanttYearLabelPlacement({
      segmentX: 960,
      segmentWidth: 40,
      chartAreaRightX,
      isLastSegment: true
    });
    expect(last.textAnchor).toBe('end');
    expect(last.x).toBeLessThanOrEqual(chartAreaRightX - 4);
    expect(last.x).toBeGreaterThan(960);

    const inner = resolveGanttYearLabelPlacement({
      segmentX: 400,
      segmentWidth: 80,
      chartAreaRightX,
      isLastSegment: false
    });
    expect(inner.textAnchor).toBe('middle');
    expect(inner.x).toBe(440);
  });

  it('clampGanttChartWidth never goes below the minimum chart width', () => {
    expect(clampGanttChartWidth(720)).toBe(720);
    expect(clampGanttChartWidth(200)).toBe(GANTT_MIN_CHART_WIDTH);
    expect(clampGanttChartWidth(GANTT_MIN_CHART_WIDTH)).toBe(GANTT_MIN_CHART_WIDTH);
  });

  it('formatIsoDateOnly returns YYYY-MM-DD for valid dates and undefined for invalid', () => {
    expect(formatIsoDateOnly(new Date('2026-03-15T12:00:00Z'))).toBe('2026-03-15');
    expect(formatIsoDateOnly(new Date('invalid'))).toBeUndefined();
  });

  it('isGanttVisibleRangeWithinPlan requires the visible window to sit inside plan bounds', () => {
    const planStart = new Date('2026-01-01').getTime();
    const planEnd = new Date('2026-12-31').getTime();
    expect(
      isGanttVisibleRangeWithinPlan(
        new Date('2026-02-01'),
        new Date('2026-06-01'),
        planStart,
        planEnd
      )
    ).toBe(true);
    expect(
      isGanttVisibleRangeWithinPlan(
        new Date('2025-12-01'),
        new Date('2026-06-01'),
        planStart,
        planEnd
      )
    ).toBe(false);
    expect(
      isGanttVisibleRangeWithinPlan(
        new Date('2026-02-01'),
        new Date('2027-01-15'),
        planStart,
        planEnd
      )
    ).toBe(false);
  });

  it('resolveGanttBarLabelPresentation clips labels to the bar width for narrow and wide bars', () => {
    const narrow = resolveGanttBarLabelPresentation(120, 48);
    expect(narrow.textAnchor).toBe('start');
    expect(narrow.x).toBe(130);
    expect(narrow.clipX).toBe(120);
    expect(narrow.clipWidth).toBe(48);

    const wide = resolveGanttBarLabelPresentation(200, 120);
    expect(wide.textAnchor).toBe('middle');
    expect(wide.x).toBe(200 + (120 - 32) / 2);
    expect(wide.clipWidth).toBe(120);
  });

  it('resolveGanttBarLabelPresentation keeps start anchor at the min-width threshold', () => {
    const atThreshold = resolveGanttBarLabelPresentation(100, 72);
    expect(atThreshold.textAnchor).toBe('start');
    expect(atThreshold.x).toBe(110);

    const aboveThreshold = resolveGanttBarLabelPresentation(100, 73);
    expect(aboveThreshold.textAnchor).toBe('middle');
    expect(aboveThreshold.x).toBe(100 + (73 - 32) / 2);
  });

  it('resolveGanttYearLabelPlacement clamps the trailing year inside the chart right edge', () => {
    const chartAreaRightX = 500;
    const cramped = resolveGanttYearLabelPlacement({
      segmentX: 480,
      segmentWidth: 40,
      chartAreaRightX,
      isLastSegment: true
    });
    expect(cramped.textAnchor).toBe('end');
    expect(cramped.x).toBe(chartAreaRightX - 4);
    expect(cramped.x).toBeLessThan(480 + 40);
  });

  it('shouldShowGanttYearOnAxis marks year breaks on January month segments after the first label', () => {
    expect(shouldShowGanttYearOnAxis(new Date('2026-01-01'), GanttTimeUnit.Month, false)).toBe(true);
    expect(shouldShowGanttYearOnAxis(new Date('2026-04-01'), GanttTimeUnit.Month, false)).toBe(false);
    expect(shouldShowGanttYearOnAxis(new Date('2026-01-01'), GanttTimeUnit.Day, false)).toBe(true);
    expect(shouldShowGanttYearOnAxis(new Date('2026-01-02'), GanttTimeUnit.Day, false)).toBe(false);
  });

  it('getNextGanttTimeSegment advances month and week boundaries', () => {
    const month = getNextGanttTimeSegment(new Date('2026-03-15'), GanttTimeUnit.Month);
    expect(month).not.toBeNull();
    expect(month!.start.toISOString().slice(0, 10)).toBe('2026-03-01');
    expect(month!.end.toISOString().slice(0, 10)).toBe('2026-04-01');

    const week = getNextGanttTimeSegment(new Date('2026-03-18'), GanttTimeUnit.Week);
    expect(week).not.toBeNull();
    expect(week!.start.getDay()).toBe(1);
    expect(daysBetween(week!.start, week!.end)).toBe(7);
  });

  it('getGanttTimeLabel appends unit suffixes for month and quarter scales', () => {
    const suffixes = { day: '日', month: '月', quarter: 'Q' };
    expect(getGanttTimeLabel(new Date('2026-03-01'), GanttTimeUnit.Month, suffixes)).toBe('3月');
    expect(getGanttTimeLabel(new Date('2026-07-01'), GanttTimeUnit.Quarter, suffixes)).toBe('Q3');
  });

  it('buildGanttTimeAxisSegments shows year on later January months', () => {
    const scale = { unit: GanttTimeUnit.Month, interval: 1 };
    const segments = buildGanttTimeAxisSegments({
      visibleStart: new Date('2026-01-01'),
      visibleEnd: new Date('2027-03-31'),
      marginLeft: 80,
      chartWidth: 900,
      timeScale: scale,
      labelSuffixes: { day: '日', month: '月', quarter: 'Q' }
    });
    const january2027 = segments.find((segment) => segment.year === 2027 && segment.month === 1);
    expect(january2027).toBeDefined();
    expect(january2027!.showYear).toBe(true);
  });

  it('computeGanttFieldRowHighlightY offsets rows below the header', () => {
    expect(
      computeGanttFieldRowHighlightY({ targetFieldIndex: 0, rowHeight: 68, headerHeight: 60 })
    ).toBe(60);
    expect(
      computeGanttFieldRowHighlightY({ targetFieldIndex: 2, rowHeight: 68, headerHeight: 60 })
    ).toBe(196);
  });

  it('computeGanttBarLabelPosition defers horizontal layout to bar label presentation', () => {
    const narrow = computeGanttBarLabelPosition({
      barX: 100,
      barWidth: 40,
      labelReserve: 32,
      barY: 200,
      barHeight: 48
    });
    expect(narrow.x).toBe(110);
    expect(narrow.y).toBe(229);
  });
});
