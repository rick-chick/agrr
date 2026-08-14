import type { PlanWorkVarianceSummaryStats } from './build-plan-work-variance-summary-stats';

export interface PlanWorkTodayAttention {
  frostRiskCount: number;
  gddDelayCount: number;
  thresholdExceededCount: number;
}

export function buildPlanWorkTodayAttention(
  varianceStats: PlanWorkVarianceSummaryStats | null,
  frostRiskCount: number
): PlanWorkTodayAttention | null {
  const gddDelayCount = varianceStats?.gddDelayCount ?? 0;
  const thresholdExceededCount = varianceStats?.thresholdExceededCount ?? 0;

  if (frostRiskCount === 0 && gddDelayCount === 0 && thresholdExceededCount === 0) {
    return null;
  }

  return {
    frostRiskCount,
    gddDelayCount,
    thresholdExceededCount
  };
}

export function hasPlanWorkTodayAttention(
  attention: PlanWorkTodayAttention | null
): boolean {
  return attention !== null;
}
