import { beforeEach, describe, expect, it } from 'vitest';
import {
  LEARN_LOOP_PHASE_ORDER,
  buildLearnLoopPhaseInputFromState,
  buildLearnLoopPhaseResult,
  countLearnProposalApplicationStatuses,
  type LearnLoopPhaseInput
} from './learn-loop-phase';
import {
  markBpTimingProposalAppliedPending,
  markStageGddProposalAppliedPending
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

  it('buildLearnLoopPhaseInputFromState derives counts from session storage', () => {
    markStageGddProposalAppliedPending(PLAN_ID, { cropId: 1, stageId: 2 });
    markBpTimingProposalAppliedPending(PLAN_ID, { cropId: 1, category: 'general' });

    const input = buildLearnLoopPhaseInputFromState({
      planId: PLAN_ID,
      actionRequiredItems: [{ field_cultivation_id: 50 }],
      stageGddProposals: [
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 2,
          stageOrder: 1,
          stageName: 'Vegetative',
          averageGddDelta: 10,
          recordedItemCount: 3,
          currentRequiredGdd: 100,
          proposedRequiredGdd: 110
        }
      ],
      blueprintTimingProposals: [
        {
          cropId: 1,
          cropName: 'Tomato',
          category: 'general',
          averageDeltaDays: 2,
          averageGddDelta: 5,
          recordedItemCount: 4,
          affectedBlueprintCount: 2,
          proposalBody: { stages: [], agricultural_tasks: [], task_schedule_blueprints: [] }
        }
      ],
      hasPostMasterConfirmation: false,
      hasMasterUpdateNextSteps: false,
      hasLearningSnapshot: false,
      carryoverSourcePlanCount: 0
    });

    expect(input.actionRequiredCount).toBe(1);
    expect(input.firstActionFieldCultivationId).toBe(50);
    expect(input.notStartedProposalCount).toBe(0);
    expect(input.appliedPendingProposalCount).toBe(2);
    expect(input.hasMasterUpdateNextSteps).toBe(true);
  });

  it('countLearnProposalApplicationStatuses tallies not_started vs applied', () => {
    markStageGddProposalAppliedPending(PLAN_ID, { cropId: 1, stageId: 2 });

    const counts = countLearnProposalApplicationStatuses(
      PLAN_ID,
      [
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 2,
          stageOrder: 1,
          stageName: 'Vegetative',
          averageGddDelta: 10,
          recordedItemCount: 3,
          currentRequiredGdd: 100,
          proposedRequiredGdd: 110
        },
        {
          cropId: 1,
          cropName: 'Tomato',
          stageId: 3,
          stageOrder: 2,
          stageName: 'Flowering',
          averageGddDelta: 5,
          recordedItemCount: 2,
          currentRequiredGdd: 80,
          proposedRequiredGdd: 85
        }
      ],
      []
    );

    expect(counts).toEqual({ notStarted: 1, appliedPending: 1 });
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
