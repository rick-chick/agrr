import type { PlanTaskScheduleItem } from './plan-schedule-snapshot';

export type PlanTaskScheduleVarianceBadgeKind =
  | 'unrecorded'
  | 'on_time'
  | 'late'
  | 'early';

export type PlanTaskScheduleVarianceBadge = {
  kind: PlanTaskScheduleVarianceBadgeKind;
  deltaDays: number | null;
};

export function resolvePlanTaskScheduleVarianceBadge(
  item: Pick<
    PlanTaskScheduleItem,
    'scheduled_date' | 'actualDate' | 'deltaDays' | 'status'
  >
): PlanTaskScheduleVarianceBadge | null {
  if (item.status.toLowerCase() === 'skipped' || item.scheduled_date == null) {
    return null;
  }

  if (item.actualDate == null || item.deltaDays == null) {
    return { kind: 'unrecorded', deltaDays: null };
  }

  if (item.deltaDays === 0) {
    return { kind: 'on_time', deltaDays: 0 };
  }

  if (item.deltaDays > 0) {
    return { kind: 'late', deltaDays: item.deltaDays };
  }

  return { kind: 'early', deltaDays: item.deltaDays };
}
