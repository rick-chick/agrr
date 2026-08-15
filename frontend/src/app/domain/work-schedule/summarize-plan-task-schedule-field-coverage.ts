export type PlanTaskScheduleFieldCoverage = {
  totalFieldCount: number;
  fieldsWithTasksCount: number;
  fieldsWithoutTasksCount: number;
  allFieldsLackTasks: boolean;
};

type FieldSchedules = {
  schedules: {
    general: ReadonlyArray<unknown>;
    fertilizer: ReadonlyArray<unknown>;
    pest_control: ReadonlyArray<unknown>;
    unscheduled: ReadonlyArray<unknown>;
  };
};

export function countFieldScheduleTasks(field: FieldSchedules): number {
  return (
    field.schedules.general.length +
    field.schedules.fertilizer.length +
    field.schedules.pest_control.length +
    field.schedules.unscheduled.length
  );
}

export function summarizePlanTaskScheduleFieldCoverage(
  fields: ReadonlyArray<FieldSchedules>
): PlanTaskScheduleFieldCoverage {
  const totalFieldCount = fields.length;
  let fieldsWithTasksCount = 0;
  for (const field of fields) {
    if (countFieldScheduleTasks(field) > 0) {
      fieldsWithTasksCount += 1;
    }
  }
  const fieldsWithoutTasksCount = totalFieldCount - fieldsWithTasksCount;
  return {
    totalFieldCount,
    fieldsWithTasksCount,
    fieldsWithoutTasksCount,
    allFieldsLackTasks: totalFieldCount > 0 && fieldsWithTasksCount === 0
  };
}
