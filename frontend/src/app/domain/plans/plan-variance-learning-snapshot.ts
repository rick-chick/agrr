import type { PlanVsActualSummary } from './plan-vs-actual-summary';

export interface PlanVarianceLearningSnapshot {
  plan_id: number;
  source_plan_id: number;
  summary: PlanVsActualSummary;
}
