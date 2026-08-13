import type { PlanVsActualSummary } from './plan-vs-actual-summary';
import type { LearnProposalApplicationStatus } from './learn-proposal-application-progress';

export interface PlanVarianceLearningSnapshot {
  plan_id: number;
  source_plan_id?: number;
  summary?: PlanVsActualSummary;
  proposal_application_progress?: Record<string, LearnProposalApplicationStatus>;
}
