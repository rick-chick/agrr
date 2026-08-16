export function formatPlanTaskScheduleAmountDeltaLabel(amountDelta: number, unit?: string | null): string {
  const rounded = Math.round(amountDelta * 100) / 100;
  const sign = rounded > 0 ? '+' : '';
  const value = `${sign}${rounded}`;
  return unit ? `${value} ${unit}` : value;
}
