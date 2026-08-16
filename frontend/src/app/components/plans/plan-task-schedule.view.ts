import type {
  CrossFarmScheduleFilterOption,
  CrossFarmScheduleRow
} from '../../domain/work-schedule/cross-farm-schedule-row';
import type { PlanTaskScheduleDisplayStatus } from '../../domain/work-schedule/resolve-plan-task-schedule-display-status';
import type { PlanTaskScheduleFertilizerSummary } from '../../domain/work-schedule/summarize-plan-task-schedule-fertilizer';
import type { PlanTaskSchedulePestControlSummary } from '../../domain/work-schedule/summarize-plan-task-schedule-pest-control';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';

export type PlanTaskScheduleCategoryFilter = 'general' | 'fertilizer' | 'pest_control' | null;

export type PlanTaskScheduleRowView = CrossFarmScheduleRow & {
  displayStatus: PlanTaskScheduleDisplayStatus;
};

export type PlanTaskScheduleMonthGroupView = {
  monthKey: string;
  rows: PlanTaskScheduleRowView[];
  averageDeltaDays: number | null;
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
  fieldFilterId: number | null;
  fieldCultivationFilterId: number | null;
  categoryFilter: PlanTaskScheduleCategoryFilter;
  fertilizerSummary: PlanTaskScheduleFertilizerSummary;
  pestControlSummary: PlanTaskSchedulePestControlSummary;
  monthGroups: PlanTaskScheduleMonthGroupView[];
  unscheduledRows: PlanTaskScheduleRowView[];
  fieldFilterOptions: CrossFarmScheduleFilterOption[];
  cropIdsForBanner: number[];
  cropNamesForBanner: Record<number, string>;
  filteredFieldCount: number;
  filteredTaskCount: number;
  regenerateRequiresConfirm: boolean;
  totalFieldCount: number;
  fieldsWithTasksCount: number;
  fieldsWithoutTasksCount: number;
  allFieldsLackTasks: boolean;
  amountDeltaByItemId: Record<number, number>;
};

export interface PlanTaskScheduleView {
  get control(): PlanTaskScheduleViewState;
  set control(value: PlanTaskScheduleViewState);
}
