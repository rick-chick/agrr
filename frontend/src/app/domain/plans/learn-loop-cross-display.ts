import {
  LEARN_LOOP_PHASE_ORDER,
  type LearnLoopPhaseId,
  type LearnLoopPhaseResult
} from './learn-loop-phase';

export type LearnNavBadge =
  | { kind: 'count'; count: number }
  | { kind: 'phase'; phase: LearnLoopPhaseId };

export interface LearnLoopCrossDisplaySummary {
  currentPhase: LearnLoopPhaseId;
  phases: ReadonlyArray<LearnLoopPhaseId>;
}

export function shouldShowLearnNavBadge(input: {
  actionRequiredCount: number;
  stageGddProposalCount: number;
  blueprintTimingProposalCount: number;
  hasActiveMasterUpdateFlow: boolean;
  hasLearningSnapshot: boolean;
  carryoverSourcePlanCount: number;
}): boolean {
  return (
    input.actionRequiredCount > 0 ||
    input.stageGddProposalCount > 0 ||
    input.blueprintTimingProposalCount > 0 ||
    input.hasActiveMasterUpdateFlow ||
    input.hasLearningSnapshot ||
    input.carryoverSourcePlanCount > 0
  );
}

export function resolveLearnNavBadge(input: {
  notStartedProposalCount: number;
  phaseResult: LearnLoopPhaseResult;
  showBadge: boolean;
}): LearnNavBadge | null {
  if (!input.showBadge) {
    return null;
  }

  if (input.notStartedProposalCount > 0) {
    return { kind: 'count', count: input.notStartedProposalCount };
  }

  return { kind: 'phase', phase: input.phaseResult.currentPhase };
}

export function learnNavBadgeAriaLabelKey(badge: LearnNavBadge): string {
  if (badge.kind === 'count') {
    return 'plans.learn.nav_badge.unapplied_count';
  }
  return 'plans.learn.nav_badge.current_phase';
}

export function learnNavBadgeAriaParams(
  badge: LearnNavBadge,
  phaseLabel?: string
): Record<string, string | number> {
  if (badge.kind === 'count') {
    return { count: badge.count };
  }
  return { phase: phaseLabel ?? badge.phase };
}

export function learnNavBadgePhaseLabelKey(phase: LearnLoopPhaseId): string {
  return `plans.learn.loop.phase.${phase}`;
}

export function buildLearnLoopCrossDisplaySummary(
  phaseResult: LearnLoopPhaseResult
): LearnLoopCrossDisplaySummary {
  return {
    currentPhase: phaseResult.currentPhase,
    phases: LEARN_LOOP_PHASE_ORDER
  };
}
