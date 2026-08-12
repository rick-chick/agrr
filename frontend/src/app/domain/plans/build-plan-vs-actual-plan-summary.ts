import type {
  PlanVsActualPlanSummaryStats,
  PlanVsActualSummary
} from './plan-vs-actual-summary';

export function buildPlanVsActualPlanSummaryStats(
  summary: PlanVsActualSummary
): PlanVsActualPlanSummaryStats {
  let completedCount = 0;
  let weightedDeltaSum = 0;

  for (const category of summary.categories) {
    completedCount += category.recorded_count;
    if (category.average_delta_days != null && category.recorded_count > 0) {
      weightedDeltaSum += category.average_delta_days * category.recorded_count;
    }
  }

  const averageDeltaDays =
    completedCount > 0 ? weightedDeltaSum / completedCount : null;

  return {
    completedCount,
    averageDeltaDays,
    unrecordedCount: summary.unrecorded_count
  };
}
