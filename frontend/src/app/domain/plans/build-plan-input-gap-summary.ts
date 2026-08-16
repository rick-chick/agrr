import type { PlanVsActualSummary } from './plan-vs-actual-summary';

export interface PlanInputGapSummary {
  unrecordedCount: number;
  actionRequiredCount: number;
  structuredUnrecordedCount: number;
  amountVarianceCount: number;
}

export function buildPlanInputGapSummary(summary: PlanVsActualSummary): PlanInputGapSummary {
  return {
    unrecordedCount: summary.unrecorded_count,
    actionRequiredCount: summary.action_required_items?.length ?? 0,
    structuredUnrecordedCount: summary.structured_unrecorded_count ?? 0,
    amountVarianceCount: summary.amount_variance_count ?? 0
  };
}
