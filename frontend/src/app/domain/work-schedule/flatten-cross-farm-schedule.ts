import type { CrossFarmScheduleRow, CrossFarmScheduleSource } from './cross-farm-schedule-row';

function compareScheduledDate(
  left: string | null | undefined,
  right: string | null | undefined
): number {
  if (!left && !right) {
    return 0;
  }
  if (!left) {
    return 1;
  }
  if (!right) {
    return -1;
  }
  return left.localeCompare(right);
}

export function flattenCrossFarmSchedules(
  sources: ReadonlyArray<CrossFarmScheduleSource>
): CrossFarmScheduleRow[] {
  const rows: CrossFarmScheduleRow[] = [];

  for (const source of sources) {
    for (const field of source.fields) {
      const scheduledTasks = [...field.schedules.general, ...field.schedules.fertilizer];
      for (const item of scheduledTasks) {
        if (!item.scheduled_date) {
          continue;
        }
        rows.push({
          item,
          farmId: source.farmId,
          farmName: source.farmName,
          planId: source.planId,
          planName: source.planName,
          fieldId: field.id,
          fieldName: field.name,
          fieldCultivationId: field.field_cultivation_id,
          cropName: field.crop_name
        });
      }

      for (const item of field.schedules.unscheduled) {
        rows.push({
          item,
          farmId: source.farmId,
          farmName: source.farmName,
          planId: source.planId,
          planName: source.planName,
          fieldId: field.id,
          fieldName: field.name,
          fieldCultivationId: field.field_cultivation_id,
          cropName: field.crop_name
        });
      }
    }
  }

  return rows.sort((left, right) =>
    compareScheduledDate(left.item.scheduled_date, right.item.scheduled_date)
  );
}
