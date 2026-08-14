import type { PlanVsActualSummary } from './plan-vs-actual-summary';

export interface PlanWorkVarianceSummaryStats {
  unrecordedCount: number;
  thresholdExceededCount: number;
  gddDelayCount: number;
}

export function buildPlanWorkVarianceSummaryStats(
  summary: PlanVsActualSummary
): PlanWorkVarianceSummaryStats {
  const actionItems = summary.action_required_items ?? [];
  const gddDelayCount = actionItems.filter(
    (item) => item.exceedance_kind === 'gdd' || item.exceedance_kind === 'both'
  ).length;

  return {
    unrecordedCount: summary.unrecorded_count,
    thresholdExceededCount: actionItems.length,
    gddDelayCount
  };
}
