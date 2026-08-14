import type { PlanVsActualSummary } from './plan-vs-actual-summary';

export interface PlanInputGapSummary {
  unrecordedCount: number;
  actionRequiredCount: number;
}

export function buildPlanInputGapSummary(summary: PlanVsActualSummary): PlanInputGapSummary {
  return {
    unrecordedCount: summary.unrecorded_count,
    actionRequiredCount: summary.action_required_items?.length ?? 0
  };
}
