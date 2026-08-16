import { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';

export type TaskScheduleItemVariance = {
  deltaDays: number | null;
  gddDelta: number | null;
};

export function collectTaskScheduleItemsForField(
  fields: FieldSchedule[],
  fieldCultivationId: number
): TaskScheduleItem[] {
  const field = fields.find((entry) => entry.field_cultivation_id === fieldCultivationId);
  if (!field) {
    return [];
  }
  return [
    ...field.schedules.general,
    ...field.schedules.fertilizer,
    ...field.schedules.pest_control,
    ...field.schedules.unscheduled
  ];
}

export function taskScheduleVarianceByItemId(
  items: TaskScheduleItem[]
): Map<number, TaskScheduleItemVariance> {
  const map = new Map<number, TaskScheduleItemVariance>();
  for (const item of items) {
    map.set(item.item_id, {
      deltaDays: item.delta_days ?? null,
      gddDelta: item.gdd_delta ?? null
    });
  }
  return map;
}
