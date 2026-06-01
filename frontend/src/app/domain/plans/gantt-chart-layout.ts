import type { CultivationData } from './cultivation-plan-data';

const CROP_FILL_COLORS = ['#9ae6b4', '#fbd38d', '#90cdf4', '#c6f6d5', '#feebc8', '#feb2b2'] as const;
const CROP_STROKE_COLORS = ['#48bb78', '#f6ad55', '#4299e1', '#2f855a', '#dd6b20', '#fc8181'] as const;

export const GANTT_MAX_VISIBLE_RANGE_MONTHS = 24;
export const GANTT_MIN_CHART_WIDTH = 400;
export const GANTT_DRAG_ACTIVATION_THRESHOLD_PX = 3;
export const GANTT_DRAG_ACTIVATION_THRESHOLD_MOBILE_PX = 12;
export const GANTT_MARGIN_LEFT_DESKTOP = 80;
export const GANTT_MARGIN_LEFT_MOBILE = 36;

export function getGanttMarginLeft(isMobileLayout: boolean): number {
  return isMobileLayout ? GANTT_MARGIN_LEFT_MOBILE : GANTT_MARGIN_LEFT_DESKTOP;
}

export function formatGanttFieldRowIndexLabel(rowIndex: number): string {
  return String(rowIndex + 1);
}

export function getGanttFieldLabelCenterX(marginLeft: number): number {
  return marginLeft / 2;
}

export function resolveGanttDragFieldContext(input: {
  targetFieldIndex: number;
  fieldGroups: ReadonlyArray<{ fieldName: string }>;
}): { rowIndex: number; fieldName: string } | null {
  if (input.targetFieldIndex < 0 || input.targetFieldIndex >= input.fieldGroups.length) {
    return null;
  }
  const group = input.fieldGroups[input.targetFieldIndex];
  return {
    rowIndex: input.targetFieldIndex + 1,
    fieldName: group.fieldName
  };
}

export function getGanttDragActivationThresholdPx(isMobileLayout: boolean): number {
  return isMobileLayout
    ? GANTT_DRAG_ACTIVATION_THRESHOLD_MOBILE_PX
    : GANTT_DRAG_ACTIVATION_THRESHOLD_PX;
}

export enum GanttTimeUnit {
  Day = 'day',
  Week = 'week',
  Month = 'month',
  Quarter = 'quarter'
}

export type GanttTimeScale = {
  unit: GanttTimeUnit;
  interval: number;
};

export type GanttTimeAxisSegment = {
  date: Date;
  year: number;
  month: number;
  quarter: number;
  week: number;
  day: number;
  label: string;
  showYear: boolean;
  showLabel: boolean;
  x: number;
  width: number;
};

export type GanttFieldGroup = {
  fieldName: string;
  fieldId: number;
  cultivations: CultivationData[];
};

export type GanttLabelSuffixes = {
  day: string;
  month: string;
  quarter: string;
};

export function normalizePlanBounds(planStart: Date, planEnd: Date): { start: Date; end: Date } {
  if (planStart.getTime() <= planEnd.getTime()) {
    return { start: new Date(planStart), end: new Date(planEnd) };
  }
  return { start: new Date(planEnd), end: new Date(planStart) };
}

export function daysBetween(d1: Date, d2: Date): number {
  return Math.floor((d2.getTime() - d1.getTime()) / (1000 * 60 * 60 * 24));
}

export type GanttBarParams = { x: number; width: number };

export function computeGanttBarParams(input: {
  cultivationStart: Date;
  cultivationEnd: Date;
  visibleStart: Date;
  visibleEnd: Date;
  marginLeft: number;
  chartWidth: number;
}): GanttBarParams | null {
  const { cultivationStart: start, cultivationEnd: end, visibleStart, visibleEnd, marginLeft, chartWidth } =
    input;

  if (isNaN(start.getTime()) || isNaN(end.getTime())) {
    return null;
  }
  if (end < visibleStart || start > visibleEnd) {
    return null;
  }

  const totalDays = Math.max(daysBetween(visibleStart, visibleEnd), 1);
  const clampedStartDate = start < visibleStart ? visibleStart : start;
  const clampedEndDate = end > visibleEnd ? visibleEnd : end;
  if (clampedEndDate < clampedStartDate) {
    return null;
  }

  const startOffsetDays = Math.max(daysBetween(visibleStart, clampedStartDate), 0);
  const visibleDays = Math.max(daysBetween(clampedStartDate, clampedEndDate) + 1, 1);
  if (visibleDays <= 0) {
    return null;
  }

  const x = marginLeft + (startOffsetDays / totalDays) * chartWidth;
  const width = (visibleDays / totalDays) * chartWidth;
  return { x, width };
}

function colorFromName(name: string, palette: readonly string[]): string {
  const hash = name.split('').reduce((acc, char) => acc + char.charCodeAt(0), 0);
  return palette[hash % palette.length];
}

export function ganttCropFillColor(cropName: string): string {
  return colorFromName(cropName, CROP_FILL_COLORS);
}

export function ganttCropStrokeColor(cropName: string): string {
  return colorFromName(cropName, CROP_STROKE_COLORS);
}

export function addMonths(date: Date, months: number): Date {
  const result = new Date(date.getTime());
  result.setMonth(result.getMonth() + months);
  return result;
}

export function formatGanttYearMonth(date: Date): string {
  const year = date.getFullYear();
  const month = (date.getMonth() + 1).toString().padStart(2, '0');
  return `${year}/${month}`;
}

export function formatGanttVisibleRangeLabel(start: Date, end: Date): string {
  return `${formatGanttYearMonth(start)}～${formatGanttYearMonth(end)}`;
}

export function buildGanttVisibleRangeFromStart(candidateStart: Date): GanttVisibleRange | null {
  const startDate = new Date(candidateStart);
  if (isNaN(startDate.getTime())) {
    return null;
  }
  const endDate = computeGanttVisibleRangeEnd(startDate);
  return {
    startDate,
    endDate,
    label: formatGanttVisibleRangeLabel(startDate, endDate)
  };
}

export function computeGanttBarParamsForPlanView(input: {
  cultivationStart: string;
  cultivationEnd: string;
  planningStartDate: string;
  planningEndDate: string;
  visibleStart: Date | null;
  visibleEnd: Date | null;
  marginLeft: number;
  chartWidth: number;
}): GanttBarParams | null {
  const { start: planStart, end: planEnd } = normalizePlanBounds(
    new Date(input.planningStartDate),
    new Date(input.planningEndDate)
  );
  const visibleStart = input.visibleStart ?? planStart;
  const visibleEnd = input.visibleEnd ?? planEnd;

  return computeGanttBarParams({
    cultivationStart: new Date(input.cultivationStart),
    cultivationEnd: new Date(input.cultivationEnd),
    visibleStart,
    visibleEnd,
    marginLeft: input.marginLeft,
    chartWidth: input.chartWidth
  });
}

export function formatIsoDateOnly(date: Date): string | undefined {
  if (isNaN(date.getTime())) {
    return undefined;
  }
  return date.toISOString().split('T')[0];
}

export function clampGanttChartWidth(containerWidth: number): number {
  return Math.max(containerWidth, GANTT_MIN_CHART_WIDTH);
}

export function computeGanttChartHeight(input: {
  marginTop: number;
  rowCount: number;
  rowHeight: number;
  marginBottom: number;
}): number {
  return input.marginTop + input.rowCount * input.rowHeight + input.marginBottom;
}

export function buildGanttFieldGroups(
  fields: ReadonlyArray<{ id: number; name: string }>,
  cultivations: CultivationData[]
): GanttFieldGroup[] {
  const sortedFields = [...fields].sort((a, b) => a.id - b.id);
  return sortedFields.map((field) => ({
    fieldName: field.name,
    fieldId: field.id,
    cultivations: cultivations.filter((c) => c.field_id === field.id)
  }));
}

export function isGanttVisibleRangeWithinPlan(
  visibleStart: Date,
  visibleEnd: Date,
  planStartTime: number,
  planEndTime: number
): boolean {
  return visibleStart.getTime() >= planStartTime && visibleEnd.getTime() <= planEndTime;
}

export function computeGanttVisibleRangeEnd(
  start: Date,
  maxMonths = GANTT_MAX_VISIBLE_RANGE_MONTHS
): Date {
  let end = addMonths(start, maxMonths);
  if (end.getTime() <= start.getTime()) {
    end = new Date(start);
  }
  return end;
}

export function shouldReinitializeGanttVisibleRange(input: {
  planStartTime: number;
  planEndTime: number;
  lastPlanStartTime: number;
  lastPlanEndTime: number;
  visibleStart: Date | null;
  visibleEnd: Date | null;
}): boolean {
  if (!input.visibleStart || !input.visibleEnd) {
    return true;
  }
  const planChanged =
    input.lastPlanStartTime !== input.planStartTime || input.lastPlanEndTime !== input.planEndTime;
  if (!planChanged) {
    return false;
  }
  return !isGanttVisibleRangeWithinPlan(
    input.visibleStart,
    input.visibleEnd,
    input.planStartTime,
    input.planEndTime
  );
}

export function getGanttTotalDays(start: Date, end: Date): number {
  return Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24));
}

export function getGanttTotalMonths(start: Date, end: Date): number {
  return (end.getFullYear() - start.getFullYear()) * 12 + (end.getMonth() - start.getMonth()) + 1;
}

export function getGanttWeekNumber(date: Date): number {
  const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
  const pastDaysOfYear = (date.getTime() - firstDayOfYear.getTime()) / 86400000;
  return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
}

export function getNextGanttTimeSegment(
  current: Date,
  unit: GanttTimeUnit
): { start: Date; end: Date } | null {
  const start = new Date(current);

  switch (unit) {
    case GanttTimeUnit.Day: {
      const end = new Date(current);
      end.setDate(end.getDate() + 1);
      return { start, end };
    }
    case GanttTimeUnit.Week: {
      const weekStart = new Date(current);
      const weekEnd = new Date(current);
      const dayOfWeek = current.getDay();
      const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
      weekStart.setDate(current.getDate() - daysToMonday);
      weekEnd.setDate(weekStart.getDate() + 7);
      return { start: weekStart, end: weekEnd };
    }
    case GanttTimeUnit.Month: {
      const monthStart = new Date(current.getFullYear(), current.getMonth(), 1);
      const monthEnd = new Date(current.getFullYear(), current.getMonth() + 1, 1);
      return { start: monthStart, end: monthEnd };
    }
    case GanttTimeUnit.Quarter: {
      const quarter = Math.floor(current.getMonth() / 3);
      const quarterStart = new Date(current.getFullYear(), quarter * 3, 1);
      const quarterEnd = new Date(current.getFullYear(), (quarter + 1) * 3, 1);
      return { start: quarterStart, end: quarterEnd };
    }
    default:
      return null;
  }
}

export function getGanttTimeLabel(start: Date, unit: GanttTimeUnit, suffixes: GanttLabelSuffixes): string {
  switch (unit) {
    case GanttTimeUnit.Day:
      return `${start.getDate()}${suffixes.day}`;
    case GanttTimeUnit.Week:
      return `${start.getMonth() + 1}/${start.getDate()}`;
    case GanttTimeUnit.Month:
      return `${start.getMonth() + 1}${suffixes.month}`;
    case GanttTimeUnit.Quarter:
      return `${suffixes.quarter}${Math.floor(start.getMonth() / 3) + 1}`;
    default:
      return `${start.getMonth() + 1}${suffixes.month}`;
  }
}

export function shouldShowGanttYearOnAxis(
  start: Date,
  unit: GanttTimeUnit,
  isFirst: boolean
): boolean {
  if (isFirst) {
    return true;
  }

  switch (unit) {
    case GanttTimeUnit.Day:
      return start.getMonth() === 0 && start.getDate() === 1;
    case GanttTimeUnit.Week:
      return start.getMonth() === 0 && getGanttWeekNumber(start) === 1;
    case GanttTimeUnit.Month:
    case GanttTimeUnit.Quarter:
      return start.getMonth() === 0;
    default:
      return start.getMonth() === 0;
  }
}

export function determineGanttTimeScale(start: Date, end: Date, chartWidth: number): GanttTimeScale {
  const totalDays = getGanttTotalDays(start, end);

  const minPixelsPerDay = 2;
  if (totalDays * minPixelsPerDay <= chartWidth) {
    const minLabelWidth = 50;
    const interval = Math.max(1, Math.ceil((totalDays * minLabelWidth) / chartWidth));
    return { unit: GanttTimeUnit.Day, interval };
  }

  const totalWeeks = Math.ceil(totalDays / 7);
  const minPixelsPerWeek = 14;
  if (totalWeeks * minPixelsPerWeek <= chartWidth) {
    const minLabelWidth = 50;
    const interval = Math.max(1, Math.ceil((totalWeeks * minLabelWidth) / chartWidth));
    return { unit: GanttTimeUnit.Week, interval };
  }

  const totalMonths = getGanttTotalMonths(start, end);
  const minPixelsPerMonth = 30;
  if (totalMonths * minPixelsPerMonth <= chartWidth) {
    const minLabelWidth = 60;
    const interval = Math.max(1, Math.ceil((totalMonths * minLabelWidth) / chartWidth));
    return { unit: GanttTimeUnit.Month, interval };
  }

  const totalQuarters = Math.ceil(totalMonths / 3);
  const minLabelWidth = 80;
  const interval = Math.max(1, Math.ceil((totalQuarters * minLabelWidth) / chartWidth));
  return { unit: GanttTimeUnit.Quarter, interval };
}

export function buildGanttTimeAxisSegments(input: {
  visibleStart: Date;
  visibleEnd: Date;
  marginLeft: number;
  chartWidth: number;
  timeScale: GanttTimeScale;
  labelSuffixes: GanttLabelSuffixes;
}): GanttTimeAxisSegment[] {
  const { visibleStart: start, visibleEnd: end, marginLeft, chartWidth, timeScale, labelSuffixes } = input;
  const totalDays = Math.max(daysBetween(start, end), 1);
  const segments: GanttTimeAxisSegment[] = [];
  let current = new Date(start);
  let x = marginLeft;
  let unitIndex = 0;
  const labelInterval = timeScale.interval;

  while (current <= end) {
    const segment = getNextGanttTimeSegment(current, timeScale.unit);
    if (!segment) {
      break;
    }

    const daysInSegment = daysBetween(current, segment.end);
    const width = (daysInSegment / totalDays) * chartWidth;
    const showLabel = unitIndex % labelInterval === 0;
    const showYear = shouldShowGanttYearOnAxis(current, timeScale.unit, unitIndex === 0);

    segments.push({
      date: new Date(current),
      year: current.getFullYear(),
      month: current.getMonth() + 1,
      quarter: Math.floor(current.getMonth() / 3) + 1,
      week: getGanttWeekNumber(current),
      day: current.getDate(),
      label: getGanttTimeLabel(current, timeScale.unit, labelSuffixes),
      showYear,
      showLabel,
      x,
      width
    });

    x += width;
    current = segment.end;
    unitIndex++;
  }

  return segments;
}

export function computeGanttBarDragStartDate(input: {
  barX: number;
  marginLeft: number;
  chartWidth: number;
  displayStart: Date;
  displayEnd: Date;
}): { daysFromStart: number; startDate: Date } {
  const totalDays = daysBetween(input.displayStart, input.displayEnd);
  const daysFromStart = Math.round(
    ((input.barX - input.marginLeft) / input.chartWidth) * totalDays
  );
  const startDate = new Date(input.displayStart);
  startDate.setDate(startDate.getDate() + daysFromStart);
  return { daysFromStart, startDate };
}

export function computeGanttTargetFieldIndex(input: {
  originalFieldIndex: number;
  deltaY: number;
  rowHeight: number;
  fieldCount: number;
}): number {
  const fieldIndexChange = Math.round(input.deltaY / input.rowHeight);
  return Math.max(
    0,
    Math.min(input.originalFieldIndex + fieldIndexChange, input.fieldCount - 1)
  );
}

export function computeCultivationDatesAfterMove(input: {
  oldStartDate: Date;
  oldCompletionDate: Date;
  newStartDate: Date;
}): { startDate: string; completionDate: string } {
  const duration = daysBetween(input.oldStartDate, input.oldCompletionDate);
  const newEndDate = new Date(input.newStartDate);
  newEndDate.setDate(newEndDate.getDate() + duration);
  return {
    startDate: formatIsoDateOnly(input.newStartDate)!,
    completionDate: formatIsoDateOnly(newEndDate)!
  };
}

export function resolveGanttDragDrop(input: {
  barX: number;
  barY: number;
  originalBarY: number;
  marginLeft: number;
  chartWidth: number;
  rowHeight: number;
  displayStart: Date;
  displayEnd: Date;
  originalFieldIndex: number;
  originalFieldName: string;
  fieldGroups: ReadonlyArray<{ fieldName: string }>;
}): {
  newFieldIndex: number;
  newFieldName: string;
  daysFromStart: number;
  newStartDate: Date;
} {
  const { daysFromStart, startDate } = computeGanttBarDragStartDate({
    barX: input.barX,
    marginLeft: input.marginLeft,
    chartWidth: input.chartWidth,
    displayStart: input.displayStart,
    displayEnd: input.displayEnd
  });
  const deltaY = input.barY - input.originalBarY;
  let newFieldIndex = computeGanttTargetFieldIndex({
    originalFieldIndex: input.originalFieldIndex,
    deltaY,
    rowHeight: input.rowHeight,
    fieldCount: input.fieldGroups.length
  });
  let newFieldName = input.originalFieldName;
  if (newFieldIndex >= 0 && newFieldIndex < input.fieldGroups.length) {
    newFieldName = input.fieldGroups[newFieldIndex].fieldName;
  } else {
    newFieldName = input.originalFieldName;
    newFieldIndex = input.originalFieldIndex;
  }
  return { newFieldIndex, newFieldName, daysFromStart, newStartDate: startDate };
}

export type GanttDragDropLayout = {
  marginLeft: number;
  chartWidth: number;
  rowHeight: number;
  displayStart: Date;
  displayEnd: Date;
};

export type GanttAdjustMove = {
  allocation_id: number;
  action: 'move';
  to_field_id: number;
  to_start_date: string;
};

export function shouldActivateGanttDrag(distancePx: number, isMobileLayout: boolean): boolean {
  return distancePx > getGanttDragActivationThresholdPx(isMobileLayout);
}

/** モバイル touch では scroll 競合の偽 pointercancel を無視する（commit は pointerup / touchend のみ） */
export function shouldIgnoreGanttPointerCancel(isMobileLayout: boolean): boolean {
  return isMobileLayout;
}

/**
 * touch リスト（touches / changedTouches）からドラッグ中ポインタの index を選ぶ。
 * 複数指で曖昧なときは null。
 */
export function pickGanttActiveTouchIndex(
  touchIdentifiers: readonly number[],
  activePointerId: number | null
): number | null {
  if (touchIdentifiers.length === 0) return null;
  if (activePointerId !== null) {
    const matched = touchIdentifiers.indexOf(activePointerId);
    if (matched >= 0) return matched;
  }
  if (touchIdentifiers.length === 1) return 0;
  return null;
}

export function collectTouchIdentifiers(
  touchCount: number,
  identifierAt: (index: number) => number | undefined
): number[] {
  const identifiers: number[] = [];
  for (let i = 0; i < touchCount; i++) {
    const id = identifierAt(i);
    if (id !== undefined) identifiers.push(id);
  }
  return identifiers;
}

export function computeGanttPointerDragDistancePx(
  clientX: number,
  clientY: number,
  startX: number,
  startY: number
): number {
  const dx = clientX - startX;
  const dy = clientY - startY;
  return Math.sqrt(dx * dx + dy * dy);
}

export function shouldShowGanttTrashDropzone(input: {
  isMobileLayout: boolean;
  isDragging: boolean;
  pointerDragDistance: number;
}): boolean {
  return (
    input.isDragging ||
    input.pointerDragDistance >
      getGanttDragActivationThresholdPx(input.isMobileLayout)
  );
}

export function resolveGanttMobileDragFieldContext(input: {
  isMobileLayout: boolean;
  isDragging: boolean;
  targetFieldIndex: number;
  originalFieldIndex: number;
  fieldGroups: ReadonlyArray<{ fieldName: string }>;
}): { rowIndex: number; fieldName: string } | null {
  if (!input.isMobileLayout || !input.isDragging) return null;
  if (input.targetFieldIndex === input.originalFieldIndex) return null;
  return resolveGanttDragFieldContext({
    targetFieldIndex: input.targetFieldIndex,
    fieldGroups: input.fieldGroups
  });
}

export function computeGanttDragPointerSvgOffset(input: {
  pointerSvgX: number;
  pointerSvgY: number;
  originalBarX: number;
  currentBarY: number;
}): { x: number; y: number } {
  return {
    x: input.pointerSvgX - input.originalBarX,
    y: input.pointerSvgY - input.currentBarY
  };
}

export type GanttRowHighlightState =
  | { visible: false }
  | { visible: true; y: number; height: number; opacity: number };

export function computeGanttDragBarSvgPosition(input: {
  pointerSvgX: number;
  pointerSvgY: number;
  initialOffset: { x: number; y: number };
  originalBarY: number;
  originalFieldIndex: number;
  rowHeight: number;
  fieldCount: number;
  headerHeight: number;
}): {
  barX: number;
  barY: number;
  targetFieldIndex: number;
  rowHighlight: GanttRowHighlightState;
} {
  const barX = input.pointerSvgX - input.initialOffset.x;
  const barY = input.pointerSvgY - input.initialOffset.y;
  const deltaY = barY - input.originalBarY;
  const targetFieldIndex = computeGanttTargetFieldIndex({
    originalFieldIndex: input.originalFieldIndex,
    deltaY,
    rowHeight: input.rowHeight,
    fieldCount: input.fieldCount
  });
  const rowHighlight: GanttRowHighlightState =
    targetFieldIndex !== input.originalFieldIndex
      ? {
          visible: true,
          y: computeGanttFieldRowHighlightY({
            targetFieldIndex,
            rowHeight: input.rowHeight,
            headerHeight: input.headerHeight
          }),
          height: input.rowHeight,
          opacity: 0.4
        }
      : { visible: false };
  return { barX, barY, targetFieldIndex, rowHighlight };
}

export function resolveGanttEffectiveDisplayRange(input: {
  dragStartDisplayStart: Date | null;
  dragStartDisplayEnd: Date | null;
  visibleStart: Date | null;
  visibleEnd: Date | null;
  planStart: Date | null;
  planEnd: Date | null;
}): { start: Date; end: Date } {
  return {
    start: input.dragStartDisplayStart ?? input.visibleStart ?? input.planStart ?? new Date(),
    end: input.dragStartDisplayEnd ?? input.visibleEnd ?? input.planEnd ?? new Date()
  };
}

export function buildGanttDragDropLayout(input: {
  marginLeft: number;
  chartWidth: number;
  rowHeight: number;
  displayStart: Date;
  displayEnd: Date;
}): GanttDragDropLayout {
  return {
    marginLeft: input.marginLeft,
    chartWidth: input.chartWidth,
    rowHeight: input.rowHeight,
    displayStart: input.displayStart,
    displayEnd: input.displayEnd
  };
}

export function resolveGanttDragCommit(input: {
  barX: number;
  barY: number;
  originalBarY: number;
  originalBarX: number;
  originalFieldIndex: number;
  originalFieldName: string;
  fieldGroups: ReadonlyArray<{ fieldName: string }>;
  layout: GanttDragDropLayout;
}): {
  shouldCommit: boolean;
  newFieldIndex: number;
  newFieldName: string;
  newStartDate: Date;
  daysOffsetDelta: number;
} {
  const dragBase = {
    marginLeft: input.layout.marginLeft,
    chartWidth: input.layout.chartWidth,
    rowHeight: input.layout.rowHeight,
    displayStart: input.layout.displayStart,
    displayEnd: input.layout.displayEnd,
    originalFieldIndex: input.originalFieldIndex,
    originalFieldName: input.originalFieldName,
    fieldGroups: input.fieldGroups
  };
  const resolved = resolveGanttDragDrop({
    barX: input.barX,
    barY: input.barY,
    originalBarY: input.originalBarY,
    ...dragBase
  });
  const originalDaysOffset = computeGanttBarDragStartDate({
    barX: input.originalBarX,
    marginLeft: dragBase.marginLeft,
    chartWidth: dragBase.chartWidth,
    displayStart: dragBase.displayStart,
    displayEnd: dragBase.displayEnd
  }).daysFromStart;
  const daysOffsetDelta = resolved.daysFromStart - originalDaysOffset;
  const shouldCommit =
    resolved.newFieldName !== input.originalFieldName || daysOffsetDelta !== 0;
  return {
    shouldCommit,
    newFieldIndex: resolved.newFieldIndex,
    newFieldName: resolved.newFieldName,
    newStartDate: resolved.newStartDate,
    daysOffsetDelta
  };
}

export function applyGanttCultivationMove(input: {
  cultivation: CultivationData;
  fieldGroups: ReadonlyArray<GanttFieldGroup>;
  newFieldName: string;
  newFieldIndex: number;
  newStartDate: Date;
}): void {
  const dates = computeCultivationDatesAfterMove({
    oldStartDate: new Date(input.cultivation.start_date),
    oldCompletionDate: new Date(input.cultivation.completion_date),
    newStartDate: input.newStartDate
  });
  input.cultivation.start_date = dates.startDate;
  input.cultivation.completion_date = dates.completionDate;
  input.cultivation.field_name = input.newFieldName;
  const targetField = input.fieldGroups[input.newFieldIndex];
  if (targetField) {
    input.cultivation.field_id = targetField.fieldId;
  }
}

export function buildGanttAdjustMove(
  cultivationId: number,
  toFieldId: number,
  newStartDate: Date
): GanttAdjustMove {
  return {
    allocation_id: cultivationId,
    action: 'move',
    to_field_id: toFieldId,
    to_start_date: formatIsoDateOnly(newStartDate)!
  };
}

export function computeGanttFieldRowHighlightY(input: {
  targetFieldIndex: number;
  rowHeight: number;
  headerHeight: number;
}): number {
  return input.headerHeight + input.targetFieldIndex * input.rowHeight;
}

export function computeGanttBarLabelPosition(input: {
  barX: number;
  barWidth: number;
  labelReserve: number;
  barY: number;
  barHeight: number;
}): { x: number; y: number } {
  const labelCenterX = input.barX + Math.max(0, (input.barWidth - input.labelReserve) / 2);
  const y = input.barY + input.barHeight / 2 + 5;
  return { x: labelCenterX, y };
}

export type GanttVisibleRange = {
  startDate: Date;
  endDate: Date;
  label: string;
};

export type GanttChartDimensions = {
  margin: { top: number; right: number; bottom: number; left: number };
  rowHeight: number;
  barHeight: number;
  barPadding: number;
  width: number;
  height: number;
};

export const DEFAULT_GANTT_CHART_DIMENSIONS: GanttChartDimensions = {
  margin: { top: 60, right: 20, bottom: 12, left: GANTT_MARGIN_LEFT_DESKTOP },
  rowHeight: 68,
  barHeight: 48,
  barPadding: 8,
  width: 1200,
  height: 500
};

export type GanttPlanDateBounds = { start: Date | null; end: Date | null };

export function parseGanttPlanBounds(
  planningStartDate: string | undefined,
  planningEndDate: string | undefined
): GanttPlanDateBounds {
  if (!planningStartDate || !planningEndDate) {
    return { start: null, end: null };
  }
  const planStartRaw = new Date(planningStartDate);
  const planEndRaw = new Date(planningEndDate);
  if (isNaN(planStartRaw.getTime()) || isNaN(planEndRaw.getTime())) {
    return { start: null, end: null };
  }
  return normalizePlanBounds(planStartRaw, planEndRaw);
}

export function buildGanttAddCropDisplayRange(input: {
  visibleStart: Date | null;
  visibleEnd: Date | null;
  planStart: Date | null;
  planEnd: Date | null;
}): { start?: string; end?: string } {
  const effectiveStart = input.visibleStart ?? input.planStart;
  const effectiveEnd = input.visibleEnd ?? input.planEnd;
  return {
    start: effectiveStart ? formatIsoDateOnly(effectiveStart) : undefined,
    end: effectiveEnd ? formatIsoDateOnly(effectiveEnd) : undefined
  };
}

export function isPointInsideClientRect(
  clientX: number,
  clientY: number,
  rect: { left: number; right: number; top: number; bottom: number }
): boolean {
  return (
    clientX >= rect.left &&
    clientX <= rect.right &&
    clientY >= rect.top &&
    clientY <= rect.bottom
  );
}
