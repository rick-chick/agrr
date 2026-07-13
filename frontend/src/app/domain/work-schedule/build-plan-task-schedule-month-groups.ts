import type { PlanFieldSchedule, PlanSchedulePlanInfo } from './plan-schedule-snapshot';
import type { CrossFarmScheduleRow } from './cross-farm-schedule-row';
import {
  filterPlanTaskScheduleRows,
  filterCrossFarmScheduleRowsFromDate
} from './filter-cross-farm-schedule';
import { flattenPlanTaskSchedule } from './flatten-plan-task-schedule';
import {
  groupCrossFarmScheduleByMonth,
  type CrossFarmScheduleMonthGroup
} from './group-cross-farm-schedule-by-month';

export function buildPlanTaskScheduleMonthGroupsFromRows(
  rows: ReadonlyArray<CrossFarmScheduleRow>,
  fieldFilterId: number | null,
  fieldCultivationFilterId: number | null,
  fromDate: string
): CrossFarmScheduleMonthGroup[] {
  const filtered = filterPlanTaskScheduleRows(rows, fieldFilterId, fieldCultivationFilterId);
  const fromDateFiltered = filterCrossFarmScheduleRowsFromDate(filtered, fromDate);
  return groupCrossFarmScheduleByMonth(fromDateFiltered);
}

export function buildPlanTaskScheduleMonthGroups(
  plan: PlanSchedulePlanInfo,
  fields: ReadonlyArray<PlanFieldSchedule>,
  fieldFilterId: number | null,
  fieldCultivationFilterId: number | null,
  fromDate: string
): CrossFarmScheduleMonthGroup[] {
  const rows = flattenPlanTaskSchedule(plan, fields);
  return buildPlanTaskScheduleMonthGroupsFromRows(
    rows,
    fieldFilterId,
    fieldCultivationFilterId,
    fromDate
  );
}
