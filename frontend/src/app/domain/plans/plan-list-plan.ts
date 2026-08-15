import type { PlanInputGapSummary } from './build-plan-input-gap-summary';
import type { PlanSummary } from './plan-summary';

export interface PlanListPlan extends PlanSummary {
  inputGap: PlanInputGapSummary | null;
}
