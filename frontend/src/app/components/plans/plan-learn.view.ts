import type {
  PlanVsActualPlanSummaryStats,
  PlanVsActualSummary
} from '../../domain/plans/plan-vs-actual-summary';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import type { StageGddCalibrationProposal } from '../../domain/plans/stage-gdd-calibration-proposal';
import type { PlanTaskScheduleRowView } from './plan-task-schedule.view';
import type { LearnPostMasterPayload } from '../../domain/plans/learn-proposal-application-progress';

export type PlanLearnViewState = {
  loading: boolean;
  error: string | null;
  planName: string | null;
  varianceLoading: boolean;
  varianceError: string | null;
  varianceSummary: PlanVsActualSummary | null;
  varianceStats: PlanVsActualPlanSummaryStats | null;
  varianceUnrecordedRows: PlanTaskScheduleRowView[];
  blueprintTimingLoading: boolean;
  blueprintTimingProposals: BlueprintTimingAdjustmentProposal[];
  stageGddProposalsLoading: boolean;
  stageGddProposals: StageGddCalibrationProposal[];
  postMasterPayload: LearnPostMasterPayload | null;
};

export interface PlanLearnView {
  get control(): PlanLearnViewState;
  set control(value: PlanLearnViewState);
}
