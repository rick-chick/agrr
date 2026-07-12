import type {
  PlanFieldSchedule,
  PlanScheduleSnapshot,
  PlanTaskScheduleItem,
  PlanTaskScheduleItemDetails
} from '../../domain/work-schedule/plan-schedule-snapshot';
import type {
  FieldSchedule,
  TaskDetails,
  TaskScheduleItem,
  TaskScheduleResponse
} from '../../models/plans/task-schedule';

function mapTaskScheduleItemDetails(details: TaskDetails): PlanTaskScheduleItemDetails {
  return {
    stageName: details.stage.name?.trim() || null,
    gddTrigger: details.gdd.trigger || null,
    gddTolerance: details.gdd.tolerance || null,
    amount: details.amount?.trim() || null,
    amountUnit: details.amount_unit?.trim() || null,
    masterName: details.master?.name?.trim() || null,
    masterDescription: details.master?.description?.trim() || null
  };
}

function mapTaskScheduleItem(item: TaskScheduleItem): PlanTaskScheduleItem {
  return {
    item_id: item.item_id,
    name: item.name,
    scheduled_date: item.scheduled_date,
    status: item.status,
    details: mapTaskScheduleItemDetails(item.details)
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
