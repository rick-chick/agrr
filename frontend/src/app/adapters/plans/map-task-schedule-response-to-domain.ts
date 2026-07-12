import type {
  PlanFieldSchedule,
  PlanScheduleSnapshot,
  PlanTaskScheduleItem
} from '../../domain/work-schedule/plan-schedule-snapshot';
import type {
  FieldSchedule,
  TaskScheduleItem,
  TaskScheduleResponse
} from '../../models/plans/task-schedule';

function mapTaskScheduleItem(item: TaskScheduleItem): PlanTaskScheduleItem {
  return {
    item_id: item.item_id,
    name: item.name,
    scheduled_date: item.scheduled_date,
    status: item.status
  };
}

function mapFieldSchedule(field: FieldSchedule): PlanFieldSchedule {
  return {
    name: field.name,
    crop_name: field.crop_name,
    field_cultivation_id: field.field_cultivation_id,
    schedules: {
      general: field.schedules.general.map(mapTaskScheduleItem),
      fertilizer: field.schedules.fertilizer.map(mapTaskScheduleItem)
    }
  };
}

export function mapTaskScheduleResponseToDomain(response: TaskScheduleResponse): PlanScheduleSnapshot {
  return {
    plan: {
      id: response.plan.id,
      name: response.plan.name
    },
    fields: response.fields.map(mapFieldSchedule)
  };
}
