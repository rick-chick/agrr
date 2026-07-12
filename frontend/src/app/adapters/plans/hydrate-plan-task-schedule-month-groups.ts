import type { CrossFarmScheduleMonthGroup } from '../../domain/work-schedule/group-cross-farm-schedule-by-month';
import type { PlanTaskScheduleMonthGroupView } from '../../components/plans/plan-task-schedule.view';
import type { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';

function indexTaskItemsById(fields: ReadonlyArray<FieldSchedule>): Map<number, TaskScheduleItem> {
  const itemsById = new Map<number, TaskScheduleItem>();
  for (const field of fields) {
    for (const item of [...field.schedules.general, ...field.schedules.fertilizer]) {
      itemsById.set(item.item_id, item);
    }
  }
  return itemsById;
}

/** Re-attaches full API task rows for view components that need TaskScheduleItem detail fields. */
export function hydratePlanTaskScheduleMonthGroups(
  groups: ReadonlyArray<CrossFarmScheduleMonthGroup>,
  fields: ReadonlyArray<FieldSchedule>
): PlanTaskScheduleMonthGroupView[] {
  const itemsById = indexTaskItemsById(fields);

  return groups.map((group) => ({
    monthKey: group.monthKey,
    rows: group.rows.map((row) => {
      const fullItem = itemsById.get(row.item.item_id);
      return {
        ...row,
        item: fullItem ?? (row.item as TaskScheduleItem)
      };
    })
  }));
}
