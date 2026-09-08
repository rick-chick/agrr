/**
 * エントリ作物スケジュールのガント横軸: 指定暦年の1月1日〜12月31日（ローカル日付）
 */
import { seasonalWrapsCalendarYear } from './entry-schedule-seasonal-wrap';

export function calendarYearJanDecBounds(year: number): { min: number; max: number; year: number } {
  const min = new Date(year, 0, 1).getTime();
  const max = new Date(year, 11, 31, 23, 59, 59, 999).getTime();
  return { min, max, year };
}

export const MONTH_NUMBERS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12] as const;

export interface TimelineBounds {
  min: number;
  max: number;
  yearLabel: string;
}

type DateRangeSummary = { start_date: string; end_date: string };

function summariesUseSeasonalWrap(
  summaries: ReadonlyArray<DateRangeSummary | null | undefined>
): boolean {
  for (const summary of summaries) {
    if (summary && seasonalWrapsCalendarYear(summary.start_date, summary.end_date)) {
      return true;
    }
  }
  return false;
}

/** 候補期間サマリからミニチャートの横軸範囲を決める（API の chart_calendar_year より実データを優先） */
export function timelineBoundsFromSummaries(
  summaries: ReadonlyArray<DateRangeSummary | null | undefined>
): TimelineBounds | null {
  const timestamps: number[] = [];
  for (const summary of summaries) {
    if (!summary) {
      continue;
    }
    const start = Date.parse(summary.start_date);
    const end = Date.parse(summary.end_date);
    if (Number.isFinite(start)) {
      timestamps.push(start);
    }
    if (Number.isFinite(end)) {
      timestamps.push(end);
    }
  }
  if (timestamps.length === 0) {
    return null;
  }

  const minTs = Math.min(...timestamps);
  const maxTs = Math.max(...timestamps);
  const minYear = new Date(minTs).getFullYear();
  const maxYear = new Date(maxTs).getFullYear();

  if (minYear === maxYear) {
    const bounds = calendarYearJanDecBounds(minYear);
    return { min: bounds.min, max: bounds.max, yearLabel: String(minYear) };
  }
  if (summariesUseSeasonalWrap(summaries)) {
    const bounds = calendarYearJanDecBounds(minYear);
    return { min: bounds.min, max: bounds.max, yearLabel: `${minYear}–${maxYear}` };
  }

  const span = maxTs - minTs;
  const pad = Math.max(span * 0.02, 86_400_000);
  return {
    min: minTs - pad,
    max: maxTs + pad,
    yearLabel: `${minYear}–${maxYear}`,
  };
}
