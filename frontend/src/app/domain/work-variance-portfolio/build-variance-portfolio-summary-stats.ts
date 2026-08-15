import type { VariancePortfolioRow } from './variance-portfolio-row';

export interface VariancePortfolioSummaryStats {
  unrecordedCount: number;
  actionRequiredCount: number;
  gddDelayCount: number;
  daysThresholdExceededCount: number;
}

export function buildVariancePortfolioSummaryStats(
  rows: ReadonlyArray<VariancePortfolioRow>
): VariancePortfolioSummaryStats {
  return rows.reduce<VariancePortfolioSummaryStats>(
    (totals, row) => ({
      unrecordedCount: totals.unrecordedCount + row.unrecordedCount,
      actionRequiredCount: totals.actionRequiredCount + row.thresholdExceededCount,
      gddDelayCount: totals.gddDelayCount + row.gddDelayCount,
      daysThresholdExceededCount:
        totals.daysThresholdExceededCount + row.daysThresholdExceededCount
    }),
    {
      unrecordedCount: 0,
      actionRequiredCount: 0,
      gddDelayCount: 0,
      daysThresholdExceededCount: 0
    }
  );
}
