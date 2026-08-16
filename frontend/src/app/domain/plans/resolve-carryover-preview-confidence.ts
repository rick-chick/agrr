import type { PlanVsActualSummary } from './plan-vs-actual-summary';
import {
  resolveLearnProposalConfidence,
  type LearnProposalConfidence
} from './resolve-learn-proposal-confidence';

export function resolveCarryoverPreviewConfidence(
  summary: PlanVsActualSummary
): LearnProposalConfidence {
  return resolveLearnProposalConfidence({
    unrecordedCount: summary.unrecorded_count,
    actionRequiredCount: summary.action_required_items?.length ?? 0
  });
}
