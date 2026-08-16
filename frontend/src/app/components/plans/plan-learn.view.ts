import type { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVarianceLearningSnapshot } from '../../domain/plans/plan-variance-learning-snapshot';
import type {
  PlanVsActualPlanSummaryStats,
  PlanVsActualSummary
} from '../../domain/plans/plan-vs-actual-summary';
import type { BlueprintAmountAdjustmentProposal } from '../../domain/plans/blueprint-amount-adjustment-proposal';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import type { LearnProposalEvidence } from '../../domain/plans/learn-proposal-evidence';
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
  blueprintTimingEvidenceByKey: Record<string, LearnProposalEvidence>;
  blueprintAmountLoading: boolean;
  blueprintAmountProposals: BlueprintAmountAdjustmentProposal[];
  blueprintAmountEvidenceByKey: Record<string, LearnProposalEvidence>;
  stageGddProposalsLoading: boolean;
  stageGddProposals: StageGddCalibrationProposal[];
  stageGddEvidenceByKey: Record<string, LearnProposalEvidence>;
  learningSnapshot: PlanVarianceLearningSnapshot | null;
  carryoverSourcePlans: PlanSummary[];
  selectedSourcePlanId: number | null;
  carryoverPreviewLoading: boolean;
  carryoverPreviewError: string | null;
  carryoverPreview: PlanVsActualSummary | null;
  carryoverImporting: boolean;
  carryoverImportError: string | null;
  postMasterPayload: LearnPostMasterPayload | null;
};

export interface PlanLearnView {
  get control(): PlanLearnViewState;
  set control(value: PlanLearnViewState);
}
