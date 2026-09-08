import { seasonalWrapsCalendarYear } from './entry-schedule-seasonal-wrap';

function toRefYearTimestamp(iso: string, refYear: number): number {
  const month = Number(iso.slice(5, 7));
  const day = Number(iso.slice(8, 10));
  return new Date(refYear, month - 1, day, 12, 0, 0, 0).getTime();
}

function computeSegmentStyle(
  start: number,
  end: number,
  ctx: { min: number; max: number }
): Record<string, string> {
  const span = ctx.max - ctx.min;
  if (!Number.isFinite(start) || !Number.isFinite(end) || !Number.isFinite(span) || span <= 0) {
    return { display: 'none' };
  }
  const leftRaw = ((start - ctx.min) / span) * 100;
  const rightRaw = ((end - ctx.min) / span) * 100;
  const leftPct = Math.max(0, Math.min(100, leftRaw));
  const rightPct = Math.max(0, Math.min(100, rightRaw));
  const widthPct = Math.max(0.5, rightPct - leftPct);
  return {
    left: `${leftPct}%`,
    width: `${widthPct}%`,
  };
}

export function segmentStyleForRange(
  startIso: string,
  endIso: string,
  ctx: { min: number; max: number }
): Record<string, string> {
  return computeSegmentStyle(Date.parse(startIso), Date.parse(endIso), ctx);
}

/** 年跨ぎの折り返し期間は 10–12 月と 1–6 月の 2 本に分け、1–12 月目盛りに合わせる */
export function segmentStylesForRange(
  startIso: string,
  endIso: string,
  ctx: { min: number; max: number }
): Array<Record<string, string>> {
  if (!seasonalWrapsCalendarYear(startIso, endIso)) {
    return [segmentStyleForRange(startIso, endIso, ctx)];
  }

  const refYear = new Date(ctx.min).getFullYear();
  const startYear = Number(startIso.slice(0, 4));
  const endYear = Number(endIso.slice(0, 4));
  const styles = [
    computeSegmentStyle(
      toRefYearTimestamp(startIso, refYear),
      toRefYearTimestamp(`${startYear}-12-31`, refYear),
      ctx
    ),
    computeSegmentStyle(
      toRefYearTimestamp(`${endYear}-01-01`, refYear),
      toRefYearTimestamp(endIso, refYear),
      ctx
    ),
  ].filter((style) => style['display'] !== 'none');

  return styles;
}
