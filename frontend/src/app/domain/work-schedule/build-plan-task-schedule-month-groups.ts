import type { FieldSchedule, PlanInfo } from '../../models/plans/task-schedule';
import {
  filterCrossFarmScheduleRows,
  filterCrossFarmScheduleRowsFromDate
} from './filter-cross-farm-schedule';
import { flattenPlanTaskSchedule } from './flatten-plan-task-schedule';
import {
  groupCrossFarmScheduleByMonth,
  type CrossFarmScheduleMonthGroup
} from './group-cross-farm-schedule-by-month';

export function buildPlanTaskScheduleMonthGroups(
  plan: PlanInfo,
  fields: ReadonlyArray<FieldSchedule>,
  fieldCultivationId: number | null,
  fromDate: string
): CrossFarmScheduleMonthGroup[] {
  const rows = flattenPlanTaskSchedule(plan, fields);
  const filtered = filterCrossFarmScheduleRows(rows, {
    farmId: null,
    fieldCultivationId
  });
  const fromDateFiltered = filterCrossFarmScheduleRowsFromDate(filtered, fromDate);
  return groupCrossFarmScheduleByMonth(fromDateFiltered);
}
