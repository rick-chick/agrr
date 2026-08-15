import type { WorkHubFarmRow } from './work-hub-farm-row';

export interface WorkHubPortfolioSummaryStats {
  unrecordedCount: number;
  actionRequiredCount: number;
  gddDelayCount: number;
  daysThresholdExceededCount: number;
}

export function buildWorkHubPortfolioSummaryStats(
  farms: WorkHubFarmRow[]
): WorkHubPortfolioSummaryStats {
  return farms.reduce<WorkHubPortfolioSummaryStats>(
    (totals, farm) => ({
      unrecordedCount: totals.unrecordedCount + farm.unrecordedCount,
      actionRequiredCount: totals.actionRequiredCount + farm.thresholdExceededCount,
      gddDelayCount: totals.gddDelayCount + farm.gddDelayCount,
      daysThresholdExceededCount:
        totals.daysThresholdExceededCount + farm.daysExceedanceCount
    }),
    {
      unrecordedCount: 0,
      actionRequiredCount: 0,
      gddDelayCount: 0,
      daysThresholdExceededCount: 0
    }
  );
}
