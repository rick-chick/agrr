import type { CrossFarmScheduleFilterOption, CrossFarmScheduleRow } from '../../domain/work-schedule/cross-farm-schedule-row';
import { TaskScheduleItem, TaskScheduleResponse } from '../../models/plans/task-schedule';

export type PlanTaskScheduleMonthRow = Omit<CrossFarmScheduleRow, 'item'> & {
  item: TaskScheduleItem;
};

export type PlanTaskScheduleMonthGroupView = {
  monthKey: string;
  rows: PlanTaskScheduleMonthRow[];
};

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
