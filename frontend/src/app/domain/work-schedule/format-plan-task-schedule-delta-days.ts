import type { PlanTaskScheduleVarianceBadge } from '../../domain/work-schedule/resolve-plan-task-schedule-variance-badge';

export function formatPlanTaskScheduleDeltaDaysLabel(
  badge: PlanTaskScheduleVarianceBadge
): string {
  switch (badge.kind) {
    case 'unrecorded':
      return '—';
    case 'on_time':
      return '±0';
    case 'late':
      return `+${badge.deltaDays}`;
    case 'early':
      return `${badge.deltaDays}`;
  }
}

export function formatPlanTaskScheduleAverageDeltaDaysLabel(average: number): string {
  const rounded = Math.round(average * 10) / 10;
  if (rounded === 0) {
    return '±0';
  }
  if (rounded > 0) {
    return `+${rounded}`;
  }
  return `${rounded}`;
}
