import type { PlanSummary } from './plan-summary';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  bpTimingProposalProgressKey,
  resolveLearnProposalApplicationStatus,
  resolveVarianceActionItemReviewStatus,
  stageGddProposalProgressKey
} from './learn-proposal-application-progress';
import {
  buildPlanDetailAdjustNavigation
} from './learn-master-update-orchestration';
import type { PlanVarianceActionItem } from './plan-vs-actual-summary';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

export const LEARN_LOOP_PHASES = ['observe', 'apply', 'reorganize', 'handover'] as const;

export type LearnLoopPhase = (typeof LEARN_LOOP_PHASES)[number];

export interface LearnLoopNextAction {
  labelKey: string;
  commands: (string | number)[];
  queryParams?: Record<string, string | number>;
}

export interface LearnLoopPhaseState {
  currentPhase: LearnLoopPhase;
  completedPhases: LearnLoopPhase[];
  nextAction: LearnLoopNextAction | null;
}

export interface LearnLoopPhaseInput {
  planId: number;
  varianceLoaded: boolean;
  actionRequiredItems: ReadonlyArray<PlanVarianceActionItem>;
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>;
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>;
  hasPendingMasterUpdate: boolean;
  hasPostMasterPayload: boolean;
  carryoverSourcePlans: ReadonlyArray<PlanSummary>;
  hasLearningSnapshot: boolean;
}

export function resolveLearnLoopPhase(input: LearnLoopPhaseInput): LearnLoopPhaseState {
  if (input.hasPendingMasterUpdate || input.hasPostMasterPayload) {
    return buildPhaseState('reorganize', resolveReorganizeNextAction(input.planId));
  }

  const unapplied = countUnappliedProposals(input);
  if (unapplied > 0) {
    return buildPhaseState('apply', resolveApplyNextAction(input));
  }

  if (
    input.carryoverSourcePlans.length > 0 &&
    !input.hasLearningSnapshot &&
    input.varianceLoaded
  ) {
    return buildPhaseState('handover', resolveHandoverNextAction(input.planId));
  }

  if (input.varianceLoaded) {
    return buildPhaseState('observe', resolveObserveNextAction(input.planId));
  }

  return buildPhaseState('observe', null);
}

function buildPhaseState(
  currentPhase: LearnLoopPhase,
  nextAction: LearnLoopNextAction | null
): LearnLoopPhaseState {
  const currentIndex = LEARN_LOOP_PHASES.indexOf(currentPhase);
  return {
    currentPhase,
    completedPhases: LEARN_LOOP_PHASES.slice(0, currentIndex),
    nextAction
  };
}

function countUnappliedProposals(input: LearnLoopPhaseInput): number {
  let count = 0;

  for (const item of input.actionRequiredItems) {
    if (resolveVarianceActionItemReviewStatus(input.planId, item.item_id) === 'not_reviewed') {
      count += 1;
    }
  }

  for (const proposal of input.stageGddProposals) {
    const key = stageGddProposalProgressKey(proposal.cropId, proposal.stageId);
    if (resolveLearnProposalApplicationStatus(input.planId, key) === 'not_started') {
      count += 1;
    }
  }

  for (const proposal of input.blueprintTimingProposals) {
    const key = bpTimingProposalProgressKey(proposal.cropId, proposal.category);
    if (resolveLearnProposalApplicationStatus(input.planId, key) === 'not_started') {
      count += 1;
    }
  }

  return count;
}

function resolveObserveNextAction(planId: number): LearnLoopNextAction {
  return {
    labelKey: 'plans.learn.loop_phase.next_action.observe',
    commands: ['/plans', planId, 'learn']
  };
}

function resolveApplyNextAction(input: LearnLoopPhaseInput): LearnLoopNextAction | null {
  const unreviewed = input.actionRequiredItems.find(
    (item) => resolveVarianceActionItemReviewStatus(input.planId, item.item_id) === 'not_reviewed'
  );
  if (unreviewed) {
    return {
      labelKey: 'plans.learn.loop_phase.next_action.apply_variance',
      commands: ['/plans', input.planId],
      queryParams: { field_cultivation_id: unreviewed.field_cultivation_id }
    };
  }

  const unappliedStageGdd = input.stageGddProposals.find((proposal) => {
    const key = stageGddProposalProgressKey(proposal.cropId, proposal.stageId);
    return resolveLearnProposalApplicationStatus(input.planId, key) === 'not_started';
  });
  if (unappliedStageGdd) {
    return {
      labelKey: 'plans.learn.loop_phase.next_action.apply_stage_gdd',
      commands: ['/plans', input.planId, 'learn']
    };
  }

  const unappliedBpTiming = input.blueprintTimingProposals.find((proposal) => {
    const key = bpTimingProposalProgressKey(proposal.cropId, proposal.category);
    return resolveLearnProposalApplicationStatus(input.planId, key) === 'not_started';
  });
  if (unappliedBpTiming) {
    return {
      labelKey: 'plans.learn.loop_phase.next_action.apply_bp_timing',
      commands: ['/plans', input.planId, 'learn']
    };
  }

  const adjust = buildPlanDetailAdjustNavigation(input.planId);
  return {
    labelKey: 'plans.learn.loop_phase.next_action.apply_variance',
    commands: adjust.commands,
    queryParams: adjust.queryParams
  };
}

function resolveReorganizeNextAction(planId: number): LearnLoopNextAction {
  const adjust = buildPlanDetailAdjustNavigation(planId);
  return {
    labelKey: 'plans.learn.loop_phase.next_action.reorganize',
    commands: adjust.commands,
    queryParams: adjust.queryParams
  };
}

function resolveHandoverNextAction(planId: number): LearnLoopNextAction {
  return {
    labelKey: 'plans.learn.loop_phase.next_action.handover',
    commands: ['/plans', planId, 'learn']
  };
}
