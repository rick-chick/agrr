import type { CrossFarmScheduleFilterOption } from '../../domain/work-schedule/cross-farm-schedule-row';
import type { CrossFarmScheduleMonthGroup } from '../../domain/work-schedule/group-cross-farm-schedule-by-month';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';

export type PlanTaskScheduleMonthGroupView = CrossFarmScheduleMonthGroup;

export type PlanTaskScheduleViewState = {
  loading: boolean;
  error: string | null;
  schedule: TaskScheduleResponse | null;
  regenerating: boolean;
  regenerateError: string | null;
  pendingSyncToastKey: string | null;
  syncReloadNonce: number;
  fromDate: string;
  fieldCultivationFilterId: number | null;
  monthGroups: PlanTaskScheduleMonthGroupView[];
  fieldFilterOptions: CrossFarmScheduleFilterOption[];
  cropIdsForBanner: number[];
  cropNamesForBanner: Record<number, string>;
};

export interface PlanTaskScheduleView {
  get control(): PlanTaskScheduleViewState;
  set control(value: PlanTaskScheduleViewState);
}
