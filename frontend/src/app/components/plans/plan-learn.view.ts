import type {
  PlanVsActualPlanSummaryStats,
  PlanVsActualSummary
} from '../../domain/plans/plan-vs-actual-summary';
import type { PlanTaskScheduleRowView } from './plan-task-schedule.view';

export type PlanLearnViewState = {
  loading: boolean;
  error: string | null;
  planName: string | null;
  varianceLoading: boolean;
  varianceError: string | null;
  varianceSummary: PlanVsActualSummary | null;
  varianceStats: PlanVsActualPlanSummaryStats | null;
  varianceUnrecordedRows: PlanTaskScheduleRowView[];
};

export interface PlanLearnView {
  get control(): PlanLearnViewState;
  set control(value: PlanLearnViewState);
}
