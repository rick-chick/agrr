import type { PlanFieldSchedule, PlanSchedulePlanInfo } from './plan-schedule-snapshot';
import {
  filterPlanTaskScheduleRows,
  filterCrossFarmScheduleRowsFromDate
} from './filter-cross-farm-schedule';
import { flattenPlanTaskSchedule } from './flatten-plan-task-schedule';
import {
  groupCrossFarmScheduleByMonth,
  type CrossFarmScheduleMonthGroup
} from './group-cross-farm-schedule-by-month';

export function buildPlanTaskScheduleMonthGroups(
  plan: PlanSchedulePlanInfo,
  fields: ReadonlyArray<PlanFieldSchedule>,
  fieldCultivationId: number | null,
  fromDate: string
): CrossFarmScheduleMonthGroup[] {
  const rows = flattenPlanTaskSchedule(plan, fields);
  const filtered = filterPlanTaskScheduleRows(rows, fieldCultivationId);
  const fromDateFiltered = filterCrossFarmScheduleRowsFromDate(filtered, fromDate);
  return groupCrossFarmScheduleByMonth(fromDateFiltered);
}
