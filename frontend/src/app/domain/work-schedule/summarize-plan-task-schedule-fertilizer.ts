import type { FieldSchedule } from '../../models/plans/task-schedule';

export type PlanTaskScheduleFertilizerSummary = {
  total: number;
  basal: number;
  topdress: number;
};

const BASAL_FERTILIZATION = 'basal_fertilization';
const TOPDRESS_FERTILIZATION = 'topdress_fertilization';

export function summarizePlanTaskScheduleFertilizer(
  fields: ReadonlyArray<FieldSchedule>
): PlanTaskScheduleFertilizerSummary {
  let basal = 0;
  let topdress = 0;

  for (const field of fields) {
    for (const item of field.schedules.fertilizer) {
      if (item.task_type === BASAL_FERTILIZATION) {
        basal += 1;
      } else if (item.task_type === TOPDRESS_FERTILIZATION) {
        topdress += 1;
      }
    }
  }

  return {
    total: basal + topdress,
    basal,
    topdress
  };
}
