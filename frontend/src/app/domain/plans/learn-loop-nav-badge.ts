import { collectLearnProposalRawSources } from './collect-learn-proposal-raw-sources';
import {
  buildLearnLoopPhaseInputFromState,
  resolveLearnLoopPhase,
  type LearnLoopPhaseId
} from './learn-loop-phase';
import { hasActiveLearnMasterUpdateFlow } from './learn-master-update-orchestration';
import { mapLearnProposalRawSourcesToPhaseProposals } from './map-learn-proposal-raw-sources-to-phase-proposals';
import type { PlanVarianceLearningSnapshot } from './plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';

export type LearnLoopNavBadgeKind = 'proposal_count' | 'phase';

export interface LearnLoopNavBadge {
  kind: LearnLoopNavBadgeKind;
  count?: number;
  phaseId?: LearnLoopPhaseId;
}

export function resolveLearnLoopNavBadge(input: {
  planId: number;
  varianceSummary: PlanVsActualSummary | null;
  learningSnapshot: PlanVarianceLearningSnapshot | null;
  carryoverSourcePlanCount?: number;
}): LearnLoopNavBadge | null {
  const rawSources = collectLearnProposalRawSources(input.varianceSummary, input.learningSnapshot);
  const { stageGddProposals, blueprintTimingProposals } =
    mapLearnProposalRawSourcesToPhaseProposals(rawSources);

  const phaseInput = buildLearnLoopPhaseInputFromState({
    planId: input.planId,
    actionRequiredItems: input.varianceSummary?.action_required_items ?? [],
    stageGddProposals,
    blueprintTimingProposals,
    hasPostMasterConfirmation: false,
    hasMasterUpdateNextSteps: hasActiveLearnMasterUpdateFlow(input.planId),
    hasLearningSnapshot: input.learningSnapshot != null,
    carryoverSourcePlanCount: input.carryoverSourcePlanCount ?? 0
  });

  if (phaseInput.notStartedProposalCount > 0) {
    return { kind: 'proposal_count', count: phaseInput.notStartedProposalCount };
  }

  const hasLearnActivity =
    phaseInput.actionRequiredCount > 0 ||
    phaseInput.stageGddProposalCount > 0 ||
    phaseInput.blueprintTimingProposalCount > 0 ||
    phaseInput.hasPostMasterConfirmation ||
    phaseInput.hasMasterUpdateNextSteps ||
    phaseInput.hasLearningSnapshot ||
    phaseInput.carryoverSourcePlanCount > 0;

  if (!hasLearnActivity) {
    return null;
  }

  const phase = resolveLearnLoopPhase(phaseInput);
  if (phase === 'complete' && phaseInput.loopComplete) {
    return null;
  }

  return { kind: 'phase', phaseId: phase };
}
