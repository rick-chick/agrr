import { collectLearnProposalRawSources } from './collect-learn-proposal-raw-sources';
import type { PlanVarianceLearningSnapshot } from './plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

export function countMergedLearnProposals(
  varianceSummary: PlanVsActualSummary | null,
  learningSnapshot: PlanVarianceLearningSnapshot | null
): number {
  const sources = collectLearnProposalRawSources(varianceSummary, learningSnapshot);
  return (
    sources.stageGddCalibrationProposals.length +
    sources.blueprintTimingAdjustmentProposals.length
  );
}
