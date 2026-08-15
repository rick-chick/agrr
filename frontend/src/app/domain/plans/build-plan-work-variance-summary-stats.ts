import type { PlanVarianceActionItem, PlanVsActualSummary } from './plan-vs-actual-summary';

export interface PlanWorkVarianceSummaryStats {
  unrecordedCount: number;
  thresholdExceededCount: number;
  gddDelayCount: number;
  daysExceedanceCount: number;
}

function isDaysExceedanceItem(item: PlanVarianceActionItem): boolean {
  return item.exceedance_kind === 'days' || item.exceedance_kind === 'both';
}

function isGddDelayItem(item: PlanVarianceActionItem): boolean {
  return item.exceedance_kind === 'gdd' || item.exceedance_kind === 'both';
}

export function buildPlanWorkVarianceSummaryStats(
  summary: PlanVsActualSummary
): PlanWorkVarianceSummaryStats {
  const actionItems = summary.action_required_items ?? [];
  const gddDelayCount = actionItems.filter(isGddDelayItem).length;
  const daysExceedanceCount = actionItems.filter(isDaysExceedanceItem).length;

  return {
    unrecordedCount: summary.unrecorded_count,
    thresholdExceededCount: actionItems.length,
    gddDelayCount,
    daysExceedanceCount
  };
}
