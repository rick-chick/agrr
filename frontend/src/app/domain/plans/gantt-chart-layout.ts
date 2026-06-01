const CROP_FILL_COLORS = ['#9ae6b4', '#fbd38d', '#90cdf4', '#c6f6d5', '#feebc8', '#feb2b2'] as const;
const CROP_STROKE_COLORS = ['#48bb78', '#f6ad55', '#4299e1', '#2f855a', '#dd6b20', '#fc8181'] as const;

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
