export function segmentStyleForRange(
  startIso: string,
  endIso: string,
  ctx: { min: number; max: number }
): Record<string, string> {
  const start = Date.parse(startIso);
  const end = Date.parse(endIso);
  const span = ctx.max - ctx.min;
  if (
    !Number.isFinite(start) ||
    !Number.isFinite(end) ||
    !Number.isFinite(span) ||
    span <= 0
  ) {
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
