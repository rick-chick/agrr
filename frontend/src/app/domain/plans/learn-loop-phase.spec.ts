import { beforeEach, describe, expect, it } from 'vitest';
import {
  LEARN_LOOP_PHASES,
  resolveLearnLoopPhase,
  type LearnLoopPhaseInput
} from './learn-loop-phase';
import {
  markStageGddProposalAppliedPending,
  markVarianceActionItemReviewed
} from './learn-proposal-application-progress';

function baseInput(overrides: Partial<LearnLoopPhaseInput> = {}): LearnLoopPhaseInput {
  return {
    planId: 7,
    varianceLoaded: true,
    actionRequiredItems: [],
    stageGddProposals: [],
    blueprintTimingProposals: [],
    hasPendingMasterUpdate: false,
    hasPostMasterPayload: false,
    carryoverSourcePlans: [],
    hasLearningSnapshot: false,
    ...overrides
  };
}

describe('resolveLearnLoopPhase', () => {
  beforeEach(() => {
    sessionStorage.clear();
  });

  it('returns observe phase when variance is loaded with no proposals to apply', () => {
    const state = resolveLearnLoopPhase(
      baseInput({
        actionRequiredItems: []
      })
    );

    expect(state.currentPhase).toBe('observe');
    expect(state.completedPhases).toEqual([]);
    expect(state.nextAction?.labelKey).toBe('plans.learn.loop_phase.next_action.observe');
  });

  it('returns apply phase when unapplied stage GDD proposals exist', () => {
    const state = resolveLearnLoopPhase(
      baseInput({
        stageGddProposals: [
          {
            cropId: 1,
            cropName: 'Tomato',
            stageId: 2,
            stageOrder: 1,
            stageName: 'Vegetative',
            averageGddDelta: 10,
            recordedItemCount: 2,
            currentRequiredGdd: 100,
            proposedRequiredGdd: 110
          }
        ]
      })
    );

    expect(state.currentPhase).toBe('apply');
    expect(state.completedPhases).toEqual(['observe']);
    expect(state.nextAction?.labelKey).toBe('plans.learn.loop_phase.next_action.apply_stage_gdd');
  });

  it('returns reorganize phase when master update confirmation is pending', () => {
    markStageGddProposalAppliedPending(7, { cropId: 1, stageId: 2 });

    const state = resolveLearnLoopPhase(
      baseInput({
        hasPendingMasterUpdate: true,
        stageGddProposals: [
          {
            cropId: 1,
            cropName: 'Tomato',
            stageId: 2,
            stageOrder: 1,
            stageName: 'Vegetative',
            averageGddDelta: 10,
            recordedItemCount: 2,
            currentRequiredGdd: 100,
            proposedRequiredGdd: 110
          }
        ]
      })
    );

    expect(state.currentPhase).toBe('reorganize');
    expect(state.completedPhases).toEqual(['observe', 'apply']);
    expect(state.nextAction?.labelKey).toBe('plans.learn.loop_phase.next_action.reorganize');
  });

  it('returns handover phase when apply and reorganize are complete with carryover sources', () => {
    markVarianceActionItemReviewed(7, 11);

    const state = resolveLearnLoopPhase(
      baseInput({
        actionRequiredItems: [
          {
            item_id: 11,
            field_cultivation_id: 100,
            category: 'general',
            name: 'Weed',
            scheduled_date: '2026-06-01',
            actual_date: '2026-06-08',
            delta_days: 7,
            gdd_trigger: 100,
            gdd_at_actual: 110,
            gdd_delta: 10,
            exceedance_kind: 'days'
          }
        ],
        carryoverSourcePlans: [{ id: 8, name: 'Source', farm_id: 1 }]
      })
    );

    expect(state.currentPhase).toBe('handover');
    expect(state.completedPhases).toEqual(['observe', 'apply', 'reorganize']);
    expect(state.nextAction?.labelKey).toBe('plans.learn.loop_phase.next_action.handover');
  });

  it('exposes all four phases in order', () => {
    expect(LEARN_LOOP_PHASES).toEqual(['observe', 'apply', 'reorganize', 'handover']);
  });
});
