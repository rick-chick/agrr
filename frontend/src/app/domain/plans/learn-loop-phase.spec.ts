import { beforeEach, describe, expect, it } from 'vitest';
import {
  LEARN_LOOP_PHASE_ORDER,
  buildLearnLoopPhaseResult,
  type LearnLoopPhaseInput
} from './learn-loop-phase';
import { markStageGddProposalAppliedPending } from './learn-proposal-application-progress';

const PLAN_ID = 7;

function baseInput(overrides: Partial<LearnLoopPhaseInput> = {}): LearnLoopPhaseInput {
  return {
    planId: PLAN_ID,
    actionRequiredCount: 0,
    stageGddProposalCount: 0,
    blueprintTimingProposalCount: 0,
    notStartedProposalCount: 0,
    appliedPendingProposalCount: 0,
    hasPostMasterConfirmation: false,
    hasMasterUpdateNextSteps: false,
    hasLearningSnapshot: false,
    carryoverSourcePlanCount: 0,
    firstActionFieldCultivationId: null,
    firstNotStartedStageGddProposal: null,
    firstNotStartedBpTimingProposal: null,
    ...overrides
  };
}

describe('LEARN_LOOP_PHASE_ORDER', () => {
  it('lists observe → apply → reorganize → handoff', () => {
    expect(LEARN_LOOP_PHASE_ORDER).toEqual(['observe', 'apply', 'reorganize', 'handoff']);
  });
});

describe('buildLearnLoopPhaseResult', () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  it('returns observe with workbench CTA when action items need review', () => {
    const result = buildLearnLoopPhaseResult(
      baseInput({
        actionRequiredCount: 2,
        firstActionFieldCultivationId: 100
      })
    );

    expect(result.currentPhase).toBe('observe');
    expect(result.nextAction).toMatchObject({
      labelKey: 'plans.learn.loop.next_action.observe_workbench',
      kind: 'router_link',
      routerLink: ['/plans', PLAN_ID],
      queryParams: { field_cultivation_id: 100 }
    });
  });

  it('returns apply with stage GDD CTA when proposals are not started', () => {
    const result = buildLearnLoopPhaseResult(
      baseInput({
        stageGddProposalCount: 1,
        notStartedProposalCount: 1,
        firstNotStartedStageGddProposal: {
          cropId: 1,
          stageId: 2,
          proposedRequiredGdd: 150
        }
      })
    );

    expect(result.currentPhase).toBe('apply');
    expect(result.nextAction).toMatchObject({
      labelKey: 'plans.learn.loop.next_action.apply_stage_gdd',
      kind: 'router_link',
      routerLink: ['/crops', '1', 'stages', '2', 'edit'],
      queryParams: {
        fromPlan: PLAN_ID,
        returnTo: 'learn',
        proposedRequiredGdd: 150
      }
    });
  });

  it('returns reorganize with placement CTA when master update is pending confirmation', () => {
    markStageGddProposalAppliedPending(PLAN_ID, { cropId: 1, stageId: 2 });

    const result = buildLearnLoopPhaseResult(
      baseInput({
        stageGddProposalCount: 1,
        appliedPendingProposalCount: 1,
        hasMasterUpdateNextSteps: true
      })
    );

    expect(result.currentPhase).toBe('reorganize');
    expect(result.nextAction).toMatchObject({
      labelKey: 'plans.learn.loop.next_action.reorganize_placement',
      kind: 'router_link',
      routerLink: ['/plans', PLAN_ID],
      queryParams: { learningOrchestration: 'adjust' }
    });
  });

  it('returns handoff with carryover scroll when apply and reorganize are complete', () => {
    const result = buildLearnLoopPhaseResult(
      baseInput({
        stageGddProposalCount: 1,
        hasLearningSnapshot: true,
        carryoverSourcePlanCount: 2
      })
    );

    expect(result.currentPhase).toBe('handoff');
    expect(result.nextAction).toMatchObject({
      labelKey: 'plans.learn.loop.next_action.handoff_carryover',
      kind: 'scroll',
      scrollTargetId: 'plan-learn-carryover-title'
    });
  });

  it('returns apply with BP timing CTA when only BP proposals are not started', () => {
    const result = buildLearnLoopPhaseResult(
      baseInput({
        blueprintTimingProposalCount: 1,
        notStartedProposalCount: 1,
        firstNotStartedBpTimingProposal: {
          cropId: 1,
          cropName: 'Tomato',
          category: 'general'
        }
      })
    );

    expect(result.currentPhase).toBe('apply');
    expect(result.nextAction).toMatchObject({
      labelKey: 'plans.learn.loop.next_action.apply_bp_timing',
      kind: 'scroll',
      scrollTargetId: 'blueprint-timing-adjustment-heading'
    });
  });
});
