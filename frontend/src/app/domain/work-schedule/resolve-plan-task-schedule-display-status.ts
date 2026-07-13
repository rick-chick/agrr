import type { PlanTaskScheduleItem } from './plan-schedule-snapshot';

export type PlanTaskScheduleDisplayStatus = 'planned' | 'completed' | 'skipped';

export function resolvePlanTaskScheduleDisplayStatus(
  item: Pick<PlanTaskScheduleItem, 'status' | 'completed'>
): PlanTaskScheduleDisplayStatus {
  if (item.completed) {
    return 'completed';
  }
  if (item.status.toLowerCase() === 'skipped') {
    return 'skipped';
  }
  return 'planned';
}
