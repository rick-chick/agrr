import type {
  CrossFarmScheduleFilterOption,
  CrossFarmScheduleRow
} from '../../domain/work-schedule/cross-farm-schedule-row';
import type { PlanTaskScheduleDisplayStatus } from '../../domain/work-schedule/resolve-plan-task-schedule-display-status';
import type {
  PlanVsActualPlanSummaryStats,
  PlanVsActualSummary
} from '../../domain/plans/plan-vs-actual-summary';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';

export type PlanTaskScheduleViewMode = 'list' | 'variance';

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
  varianceLoading: boolean;
  varianceError: string | null;
  varianceSummary: PlanVsActualSummary | null;
  varianceStats: PlanVsActualPlanSummaryStats | null;
  varianceUnrecordedRows: PlanTaskScheduleRowView[];
};

export interface PlanTaskScheduleView {
  get control(): PlanTaskScheduleViewState;
  set control(value: PlanTaskScheduleViewState);
}
