export interface VariancePortfolioRow {
  farmId: number;
  farmName: string;
  planId: number;
  planYear: number | null;
  status: string;
  unrecordedCount: number;
  gddDelayCount: number;
  thresholdExceededCount: number;
  daysThresholdExceededCount: number;
  carryoverNotImported: boolean;
  weatherTriggerCount: number;
}
