import type { FieldSchedule, PlanInfo } from '../../models/plans/task-schedule';
import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';
import { flattenCrossFarmSchedules } from './flatten-cross-farm-schedule';

export function flattenPlanTaskSchedule(
  plan: PlanInfo,
  fields: ReadonlyArray<FieldSchedule>
): CrossFarmScheduleRow[] {
  if (fields.length === 0) {
    return [];
  }

  return flattenCrossFarmSchedules([
    {
      farmId: 0,
      farmName: '',
      planId: plan.id,
      planName: plan.name,
      fields: fields.map((field) => ({
        name: field.name,
        crop_name: field.crop_name,
        field_cultivation_id: field.field_cultivation_id,
        schedules: {
          general: field.schedules.general,
          fertilizer: field.schedules.fertilizer
        }
      }))
    }
  ]);
}
