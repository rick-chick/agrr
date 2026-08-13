import { beforeEach, describe, expect, it } from 'vitest';
import {
  LEARN_LOOP_PHASE_ORDER,
  areAllLearnProposalsResolved,
  buildLearnLoopPhaseInputFromState,
  buildLearnLoopPhaseResult,
  countLearnProposalApplicationStatuses,
  isLearnLoopComplete,
  type LearnLoopPhaseInput
} from './learn-loop-phase';
import {
  markAllConfirmedProposalsDone,
  markBpTimingProposalAppliedPending,
  markBpTimingProposalDismissed,
  markStageGddProposalAppliedPending,
  markStageGddProposalDismissed,
  markLearnProposalConfirmed,
  markLearnProposalDismissed,
  stageGddProposalProgressKey
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

describe('LEARN_LOOP_PHASE_ORDER', () => {
  it('lists observe → apply → reorganize → handoff → complete', () => {
    expect(LEARN_LOOP_PHASE_ORDER).toEqual([
      'observe',
      'apply',
      'reorganize',
      'handoff',
      'complete'
    ]);
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

    expect(counts).toEqual({ notStarted: 1, appliedPending: 1, resolved: 0 });
  });

  it('areAllLearnProposalsResolved is true when every proposal is done or dismissed', () => {
    const stageGddProposals = [
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
    ];
    const blueprintTimingProposals = [
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
    ];

    expect(
      areAllLearnProposalsResolved(PLAN_ID, stageGddProposals, blueprintTimingProposals)
    ).toBe(false);

    markLearnProposalDismissed(PLAN_ID, stageGddProposalProgressKey(1, 2));
    expect(
      areAllLearnProposalsResolved(PLAN_ID, stageGddProposals, blueprintTimingProposals)
    ).toBe(false);

    markLearnProposalDismissed(PLAN_ID, 'bp_timing:1:general');
    expect(
      areAllLearnProposalsResolved(PLAN_ID, stageGddProposals, blueprintTimingProposals)
    ).toBe(true);
  });

  it('returns complete with reorganize and next-plan CTAs when all proposals are resolved', () => {
    const key = stageGddProposalProgressKey(1, 2);
    markStageGddProposalAppliedPending(PLAN_ID, { cropId: 1, stageId: 2 });
    markLearnProposalConfirmed(PLAN_ID, key);
    markAllConfirmedProposalsDone(PLAN_ID);

    const result = buildLearnLoopPhaseResult(
      baseInput({
        stageGddProposalCount: 1,
        allProposalsResolved: true
      })
    );

    expect(result.currentPhase).toBe('complete');
    expect(result.nextAction).toMatchObject({
      labelKey: 'plans.learn.loop.next_action.complete_reorganize',
      kind: 'router_link',
      routerLink: ['/plans', PLAN_ID],
      queryParams: { learningOrchestration: 'adjust' }
    });
    expect(result.secondaryAction).toMatchObject({
      labelKey: 'plans.learn.loop.next_action.complete_next_plan',
      kind: 'router_link',
      routerLink: ['/plans']
    });
  });

  it('countLearnProposalApplicationStatuses excludes dismissed and done from pending counts', () => {
    markLearnProposalDismissed(PLAN_ID, stageGddProposalProgressKey(1, 2));
    markStageGddProposalAppliedPending(PLAN_ID, { cropId: 1, stageId: 3 });

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

    expect(counts).toEqual({ notStarted: 0, appliedPending: 1, resolved: 1 });
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

  it('excludes dismissed proposals from not_started and applied_pending counts', () => {
    markStageGddProposalDismissed(PLAN_ID, { cropId: 1, stageId: 2 });
    markBpTimingProposalAppliedPending(PLAN_ID, { cropId: 1, category: 'general' });

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
      [
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
      ]
    );

    expect(counts).toEqual({ notStarted: 1, appliedPending: 1, resolved: 1 });
  });

  it('returns loop complete next action when all proposals are done or dismissed', () => {
    markStageGddProposalDismissed(PLAN_ID, { cropId: 1, stageId: 2 });
    markBpTimingProposalDismissed(PLAN_ID, { cropId: 1, category: 'general' });

    const stageGddProposals = [
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
    ];
    const blueprintTimingProposals = [
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
    ];

    expect(
      isLearnLoopComplete(PLAN_ID, stageGddProposals, blueprintTimingProposals)
    ).toBe(true);

    const result = buildLearnLoopPhaseResult(
      baseInput({
        stageGddProposalCount: 1,
        blueprintTimingProposalCount: 1,
        notStartedProposalCount: 0,
        appliedPendingProposalCount: 0,
        loopComplete: true,
        hasLearningSnapshot: true,
        carryoverSourcePlanCount: 2
      })
    );

    expect(result.currentPhase).toBe('handoff');
    expect(result.nextAction).toMatchObject({
      labelKey: 'plans.learn.loop.next_action.loop_complete_next_plan',
      kind: 'scroll',
      scrollTargetId: 'plan-learn-carryover-title'
    });
  });

  it('isLearnLoopComplete is false when any proposal is not done or dismissed', () => {
    markStageGddProposalDismissed(PLAN_ID, { cropId: 1, stageId: 2 });

    expect(
      isLearnLoopComplete(
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
          }
        ],
        [
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
        ]
      )
    ).toBe(false);
  });

  it('isLearnLoopComplete is true when applied proposals reach done', () => {
    const key = stageGddProposalProgressKey(1, 2);
    markStageGddProposalAppliedPending(PLAN_ID, { cropId: 1, stageId: 2 });
    markLearnProposalConfirmed(PLAN_ID, key);
    markAllConfirmedProposalsDone(PLAN_ID);
    markBpTimingProposalDismissed(PLAN_ID, { cropId: 1, category: 'general' });

    expect(
      isLearnLoopComplete(
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
          }
        ],
        [
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
        ]
      )
    ).toBe(true);
  });
});
