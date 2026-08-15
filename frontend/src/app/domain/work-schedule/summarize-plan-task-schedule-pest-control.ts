import type { FieldSchedule } from '../../models/plans/task-schedule';

export type PlanTaskSchedulePestControlSummary = {
  total: number;
  preventive: number;
  curative: number;
};

const PREVENTIVE_SPRAY = 'preventive_spray';
const CURATIVE_SPRAY = 'curative_spray';

export function summarizePlanTaskSchedulePestControl(
  fields: ReadonlyArray<FieldSchedule>
): PlanTaskSchedulePestControlSummary {
  let preventive = 0;
  let curative = 0;

  for (const field of fields) {
    for (const item of field.schedules.pest_control) {
      if (item.task_type === PREVENTIVE_SPRAY) {
        preventive += 1;
      } else if (item.task_type === CURATIVE_SPRAY) {
        curative += 1;
      }
    }
  }

  return {
    total: preventive + curative,
    preventive,
    curative
  };
}
