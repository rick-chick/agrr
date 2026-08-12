import type { PlanTaskScheduleItem } from './plan-schedule-snapshot';

export function computePlanTaskScheduleMonthAverageDelta(
  items: ReadonlyArray<Pick<PlanTaskScheduleItem, 'deltaDays' | 'status' | 'scheduled_date'>>
): number | null {
  const deltas = items
    .filter(
      (item) =>
        item.status.toLowerCase() !== 'skipped' &&
        item.scheduled_date != null &&
        item.deltaDays != null
    )
    .map((item) => item.deltaDays as number);

  if (deltas.length === 0) {
    return null;
  }

  const sum = deltas.reduce((total, delta) => total + delta, 0);
  return sum / deltas.length;
}
