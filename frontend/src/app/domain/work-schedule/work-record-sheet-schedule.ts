import { FieldSchedule } from '../../models/plans/task-schedule';

export type WorkRecordScheduleCategory = 'general' | 'fertilizer' | 'pest_control' | null;

const FERTILIZER_TASK_TYPES = new Set(['fertilizer', 'basal_fertilization', 'topdress_fertilization']);
const PEST_CONTROL_TASK_TYPES = new Set(['pest_control', 'preventive_spray', 'curative_spray']);

export function scheduleCategoryFromTaskType(
  taskType: string | null | undefined
): WorkRecordScheduleCategory {
  if (!taskType) {
    return null;
  }
  if (FERTILIZER_TASK_TYPES.has(taskType)) {
    return 'fertilizer';
  }
  if (PEST_CONTROL_TASK_TYPES.has(taskType)) {
    return 'pest_control';
  }
  if (taskType === 'general') {
    return 'general';
  }
  return null;
}

export function resolveCropIdForFieldCultivation(
  fields: readonly FieldSchedule[],
  fieldCultivationId: number | null | undefined
): number | null {
  if (fieldCultivationId == null) {
    return null;
  }
  return fields.find((field) => field.field_cultivation_id === fieldCultivationId)?.crop_id ?? null;
}
