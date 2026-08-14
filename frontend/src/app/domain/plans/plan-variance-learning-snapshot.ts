import type { PlanVsActualSummary } from './plan-vs-actual-summary';
import type { LearnProposalApplicationStatus } from './learn-proposal-application-progress';
import type { ReorganizeOrchestrationProgress } from './learn-master-update-orchestration';
import type { CropSetupProposalBody } from '../crops/crop-setup-proposal';
import type { LearnBpTimingApplyContext, LearnPostMasterPayload } from './learn-proposal-application-progress';

export interface LearnHandoffState {
  post_master_payload?: LearnPostMasterPayload | null;
  bp_timing_apply_context?: LearnBpTimingApplyContext | null;
  blueprint_prefill_by_crop_id?: Record<string, CropSetupProposalBody>;
}

export interface PlanVarianceLearningSnapshot {
  plan_id: number;
  source_plan_id?: number;
  summary?: PlanVsActualSummary;
  proposal_application_progress?: Record<string, LearnProposalApplicationStatus>;
  reorganize_orchestration_progress?: ReorganizeOrchestrationProgress;
  learn_handoff?: LearnHandoffState;
}
