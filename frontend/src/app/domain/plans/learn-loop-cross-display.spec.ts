import { beforeEach, describe, expect, it } from 'vitest';
import {
  buildLearnLoopCrossDisplaySummary,
  resolveLearnNavBadge,
  shouldShowLearnNavBadge
} from './learn-loop-cross-display';
import { buildLearnLoopPhaseResult, type LearnLoopPhaseInput } from './learn-loop-phase';
import {
  clearLearnProposalApplicationProgressCache,
  markStageGddProposalDismissed
} from './learn-proposal-application-progress';

const PLAN_ID = 7;

function baseInput(overrides: Partial<LearnLoopPhaseInput> = {}): LearnLoopPhaseInput {
  return {
    planId: PLAN_ID,
    actionRequiredCount: 0,
    stageGddProposalCount: 0,
    blueprintTimingProposalCount: 0,
    notStartedProposalCount: 0,
    appliedPendingProposalCount: 0,
    loopComplete: false,
    hasPostMasterConfirmation: false,
    hasMasterUpdateNextSteps: false,
    hasLearningSnapshot: false,
    carryoverSourcePlanCount: 0,
    firstActionFieldCultivationId: null,
    firstNotStartedStageGddProposal: null,
    firstNotStartedBpTimingProposal: null,
    allProposalsResolved: false,
    ...overrides
  };
}

describe('shouldShowLearnNavBadge', () => {
  it('returns false when there is no learn activity', () => {
    expect(
      shouldShowLearnNavBadge({
        actionRequiredCount: 0,
        stageGddProposalCount: 0,
        blueprintTimingProposalCount: 0,
        hasActiveMasterUpdateFlow: false,
        hasLearningSnapshot: false,
        carryoverSourcePlanCount: 0
      })
    ).toBe(false);
  });

  it('returns true when action items or proposals exist', () => {
    expect(
      shouldShowLearnNavBadge({
        actionRequiredCount: 2,
        stageGddProposalCount: 0,
        blueprintTimingProposalCount: 0,
        hasActiveMasterUpdateFlow: false,
        hasLearningSnapshot: false,
        carryoverSourcePlanCount: 0
      })
    ).toBe(true);
  });
});

describe('resolveLearnNavBadge', () => {
  beforeEach(() => {
    sessionStorage.clear();
    clearLearnProposalApplicationProgressCache();
  });

  it('returns null when learn activity is absent', () => {
    const phaseResult = buildLearnLoopPhaseResult(baseInput());
    expect(
      resolveLearnNavBadge({
        notStartedProposalCount: 0,
        phaseResult,
        showBadge: false
      })
    ).toBeNull();
  });

  it('returns count badge when unapplied proposals remain', () => {
    const phaseResult = buildLearnLoopPhaseResult(
      baseInput({
        notStartedProposalCount: 3,
        stageGddProposalCount: 3
      })
    );
    expect(
      resolveLearnNavBadge({
        notStartedProposalCount: 3,
        phaseResult,
        showBadge: true
      })
    ).toEqual({ kind: 'count', count: 3 });
  });

  it('returns phase badge when proposals are handled but loop is active', () => {
    markStageGddProposalDismissed(PLAN_ID, { cropId: 1, stageId: 2 });
    const phaseResult = buildLearnLoopPhaseResult(
      baseInput({
        actionRequiredCount: 1,
        firstActionFieldCultivationId: 42
      })
    );
    expect(
      resolveLearnNavBadge({
        notStartedProposalCount: 0,
        phaseResult,
        showBadge: true
      })
    ).toEqual({ kind: 'phase', phase: 'observe' });
  });
});

describe('buildLearnLoopCrossDisplaySummary', () => {
  it('includes current phase and compact phase order for banners', () => {
    const summary = buildLearnLoopCrossDisplaySummary(
      buildLearnLoopPhaseResult(
        baseInput({
          actionRequiredCount: 1,
          firstActionFieldCultivationId: 10
        })
      )
    );

    expect(summary.currentPhase).toBe('observe');
    expect(summary.phases).toEqual(['observe', 'apply', 'reorganize', 'handoff', 'complete']);
    expect(summary.completedPhaseCount).toBe(0);
  });
});
