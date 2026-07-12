import type { PlanFieldSchedule, PlanSchedulePlanInfo } from './plan-schedule-snapshot';
import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';
import { flattenCrossFarmSchedules } from './flatten-cross-farm-schedule';

export function flattenPlanTaskSchedule(
  plan: PlanSchedulePlanInfo,
  fields: ReadonlyArray<PlanFieldSchedule>
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
