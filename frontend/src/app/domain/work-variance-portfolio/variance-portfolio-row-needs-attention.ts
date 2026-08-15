import type { VariancePortfolioRow } from './variance-portfolio-row';

export function variancePortfolioRowNeedsAttention(row: VariancePortfolioRow): boolean {
  return (
    row.unrecordedCount > 0 ||
    row.gddDelayCount > 0 ||
    row.thresholdExceededCount > 0 ||
    row.daysThresholdExceededCount > 0
  );
}
