import {
  buildPlanDetailAdjustNavigation,
  hasPendingMasterUpdateConfirmation
} from './learn-master-update-orchestration';
import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';
import {
  bpTimingProposalProgressKey,
  isLearnProposalResolved,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey,
  type LearnProposalApplicationStatus
} from './learn-proposal-application-progress';

export type LearnLoopPhaseId = 'observe' | 'apply' | 'reorganize' | 'handoff' | 'complete';

export const LEARN_LOOP_PHASE_ORDER: ReadonlyArray<LearnLoopPhaseId> = [
  'observe',
  'apply',
  'reorganize',
  'handoff',
  'complete'
];

export interface LearnLoopPhaseInput {
  planId: number;
  actionRequiredCount: number;
  stageGddProposalCount: number;
  blueprintTimingProposalCount: number;
  notStartedProposalCount: number;
  appliedPendingProposalCount: number;
  loopComplete: boolean;
  hasPostMasterConfirmation: boolean;
  hasMasterUpdateNextSteps: boolean;
  hasLearningSnapshot: boolean;
  carryoverSourcePlanCount: number;
  firstActionFieldCultivationId: number | null;
  firstNotStartedStageGddProposal: Pick<
    StageGddCalibrationProposal,
    'cropId' | 'stageId' | 'proposedRequiredGdd'
  > | null;
  firstNotStartedBpTimingProposal: Pick<
    BlueprintTimingAdjustmentProposal,
    'cropId' | 'cropName' | 'category'
  > | null;
  allProposalsResolved: boolean;
}

export type LearnLoopNextActionKind = 'router_link' | 'scroll';

export interface LearnLoopNextAction {
  labelKey: string;
  kind: LearnLoopNextActionKind;
  routerLink?: (string | number)[];
  queryParams?: Record<string, string | number>;
  scrollTargetId?: string;
}

export interface LearnLoopPhaseResult {
  currentPhase: LearnLoopPhaseId;
  nextAction: LearnLoopNextAction | null;
  secondaryAction?: LearnLoopNextAction | null;
}

export function areAllLearnProposalsResolved(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): boolean {
  const totalCount = stageGddProposals.length + blueprintTimingProposals.length;
  if (totalCount === 0) {
    return false;
  }

  for (const proposal of stageGddProposals) {
    const status = resolveLearnProposalApplicationStatus(
      planId,
      stageGddProposalProgressKey(proposal.cropId, proposal.stageId)
    );
    if (!isLearnProposalResolved(status)) {
      return false;
    }
  }

  for (const proposal of blueprintTimingProposals) {
    const status = resolveLearnProposalApplicationStatus(
      planId,
      bpTimingProposalProgressKey(proposal.cropId, proposal.category)
    );
    if (!isLearnProposalResolved(status)) {
      return false;
    }
  }

  return true;
}

export function countLearnProposalApplicationStatuses(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): { notStarted: number; appliedPending: number; resolved: number } {
  let notStarted = 0;
  let appliedPending = 0;
  let resolved = 0;

  for (const proposal of stageGddProposals) {
    tallyProposalStatus(
      resolveLearnProposalApplicationStatus(
        planId,
        stageGddProposalProgressKey(proposal.cropId, proposal.stageId)
      ),
      (n) => (notStarted += n),
      (n) => (appliedPending += n)
    );
  }

  for (const proposal of blueprintTimingProposals) {
    tallyProposalStatus(
      resolveLearnProposalApplicationStatus(
        planId,
        bpTimingProposalProgressKey(proposal.cropId, proposal.category)
      ),
      (n) => (notStarted += n),
      (n) => (appliedPending += n)
    );
  }

  return { notStarted, appliedPending };
}

function tallyProposalStatus(
  status: LearnProposalApplicationStatus,
  addNotStarted: (count: number) => void,
  addAppliedPending: (count: number) => void
): void {
  if (status === 'not_started') {
    addNotStarted(1);
  } else if (status === 'applied_pending_confirmation' || status === 'confirmed') {
    addAppliedPending(1);
  }
}

export function isLearnLoopComplete(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): boolean {
  const totalProposals = stageGddProposals.length + blueprintTimingProposals.length;
  if (totalProposals === 0) {
    return false;
  }

  for (const proposal of stageGddProposals) {
    const status = resolveLearnProposalApplicationStatus(
      planId,
      stageGddProposalProgressKey(proposal.cropId, proposal.stageId)
    );
    if (status !== 'done' && status !== 'dismissed') {
      return false;
    }
  }

  for (const proposal of blueprintTimingProposals) {
    const status = resolveLearnProposalApplicationStatus(
      planId,
      bpTimingProposalProgressKey(proposal.cropId, proposal.category)
    );
    if (status !== 'done' && status !== 'dismissed') {
      return false;
    }
  }

  return true;
}

export function findFirstNotStartedStageGddProposal(
  planId: number,
  proposals: ReadonlyArray<StageGddCalibrationProposal>
): Pick<StageGddCalibrationProposal, 'cropId' | 'stageId' | 'proposedRequiredGdd'> | null {
  for (const proposal of proposals) {
    const status = resolveLearnProposalApplicationStatus(
      planId,
      stageGddProposalProgressKey(proposal.cropId, proposal.stageId)
    );
    if (status === 'not_started') {
      return proposal;
    }
  }
  return null;
}

export function findFirstNotStartedBpTimingProposal(
  planId: number,
  proposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): Pick<BlueprintTimingAdjustmentProposal, 'cropId' | 'cropName' | 'category'> | null {
  for (const proposal of proposals) {
    const status = resolveLearnProposalApplicationStatus(
      planId,
      bpTimingProposalProgressKey(proposal.cropId, proposal.category)
    );
    if (status === 'not_started') {
      return proposal;
    }
  }
  return null;
}

export function resolveLearnLoopPhase(input: LearnLoopPhaseInput): LearnLoopPhaseId {
  if (
    input.hasPostMasterConfirmation ||
    input.hasMasterUpdateNextSteps ||
    input.appliedPendingProposalCount > 0
  ) {
    return 'reorganize';
  }

  if (input.notStartedProposalCount > 0) {
    return 'apply';
  }

  if (input.loopComplete) {
    return 'handoff';
  }

  const hasMasterProposals =
    input.stageGddProposalCount > 0 || input.blueprintTimingProposalCount > 0;

  if (hasMasterProposals && input.allProposalsResolved) {
    return 'complete';
  }

  if (
    hasMasterProposals &&
    (input.hasLearningSnapshot ||
      (input.carryoverSourcePlanCount > 0 && input.actionRequiredCount === 0))
  ) {
    return 'handoff';
  }

  if (input.actionRequiredCount > 0 || hasMasterProposals) {
    return 'observe';
  }

  if (input.carryoverSourcePlanCount > 0) {
    return 'handoff';
  }

  return 'observe';
}

export function resolveLearnLoopNextAction(input: LearnLoopPhaseInput): LearnLoopNextAction | null {
  const phase = resolveLearnLoopPhase(input);

  switch (phase) {
    case 'observe':
      if (input.firstActionFieldCultivationId != null) {
        return {
          labelKey: 'plans.learn.loop.next_action.observe_workbench',
          kind: 'router_link',
          routerLink: ['/plans', input.planId],
          queryParams: { field_cultivation_id: input.firstActionFieldCultivationId }
        };
      }
      if (input.stageGddProposalCount > 0 || input.blueprintTimingProposalCount > 0) {
        return {
          labelKey: 'plans.learn.loop.next_action.observe_proposals',
          kind: 'scroll',
          scrollTargetId: 'plan-learn-loop-proposals'
        };
      }
      return null;

    case 'apply':
      if (input.firstNotStartedStageGddProposal) {
        const proposal = input.firstNotStartedStageGddProposal;
        return {
          labelKey: 'plans.learn.loop.next_action.apply_stage_gdd',
          kind: 'router_link',
          routerLink: [
            '/crops',
            String(proposal.cropId),
            'stages',
            String(proposal.stageId),
            'edit'
          ],
          queryParams: {
            fromPlan: input.planId,
            returnTo: 'learn',
            proposedRequiredGdd: proposal.proposedRequiredGdd ?? ''
          }
        };
      }
      if (input.firstNotStartedBpTimingProposal) {
        return {
          labelKey: 'plans.learn.loop.next_action.apply_bp_timing',
          kind: 'scroll',
          scrollTargetId: 'blueprint-timing-adjustment-heading'
        };
      }
      return null;

    case 'reorganize':
      const adjust = buildPlanDetailAdjustNavigation(input.planId);
      return {
        labelKey: 'plans.learn.loop.next_action.reorganize_placement',
        kind: 'router_link',
        routerLink: adjust.commands,
        queryParams: adjust.queryParams
      };

    case 'handoff':
      if (input.loopComplete) {
        return {
          labelKey: 'plans.learn.loop.next_action.loop_complete_next_plan',
          kind: 'scroll',
          scrollTargetId: 'plan-learn-carryover-title'
        };
      }
      return {
        labelKey: 'plans.learn.loop.next_action.handoff_carryover',
        kind: 'scroll',
        scrollTargetId: 'plan-learn-carryover-title'
      };

    case 'complete': {
      const adjust = buildPlanDetailAdjustNavigation(input.planId);
      return {
        labelKey: 'plans.learn.loop.next_action.complete_reorganize',
        kind: 'router_link',
        routerLink: adjust.commands,
        queryParams: adjust.queryParams
      };
    }
  }
}

export function resolveLearnLoopSecondaryAction(
  input: LearnLoopPhaseInput
): LearnLoopNextAction | null {
  if (resolveLearnLoopPhase(input) !== 'complete') {
    return null;
  }

  return {
    labelKey: 'plans.learn.loop.next_action.complete_next_plan',
    kind: 'router_link',
    routerLink: ['/plans']
  };
}

export function buildLearnLoopPhaseResult(input: LearnLoopPhaseInput): LearnLoopPhaseResult {
  return {
    currentPhase: resolveLearnLoopPhase(input),
    nextAction: resolveLearnLoopNextAction(input),
    secondaryAction: resolveLearnLoopSecondaryAction(input)
  };
}

export function buildLearnLoopPhaseInputFromState(input: {
  planId: number;
  actionRequiredItems: ReadonlyArray<{ field_cultivation_id: number }>;
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>;
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>;
  hasPostMasterConfirmation: boolean;
  hasMasterUpdateNextSteps: boolean;
  hasLearningSnapshot: boolean;
  carryoverSourcePlanCount: number;
}): LearnLoopPhaseInput {
  const counts = countLearnProposalApplicationStatuses(
    input.planId,
    input.stageGddProposals,
    input.blueprintTimingProposals
  );

  return {
    planId: input.planId,
    actionRequiredCount: input.actionRequiredItems.length,
    stageGddProposalCount: input.stageGddProposals.length,
    blueprintTimingProposalCount: input.blueprintTimingProposals.length,
    notStartedProposalCount: counts.notStarted,
    appliedPendingProposalCount: counts.appliedPending,
    loopComplete: isLearnLoopComplete(
      input.planId,
      input.stageGddProposals,
      input.blueprintTimingProposals
    ),
    hasPostMasterConfirmation: input.hasPostMasterConfirmation,
    hasMasterUpdateNextSteps:
      input.hasMasterUpdateNextSteps ||
      hasPendingMasterUpdateConfirmation(input.planId),
    hasLearningSnapshot: input.hasLearningSnapshot,
    carryoverSourcePlanCount: input.carryoverSourcePlanCount,
    firstActionFieldCultivationId:
      input.actionRequiredItems[0]?.field_cultivation_id ?? null,
    firstNotStartedStageGddProposal: findFirstNotStartedStageGddProposal(
      input.planId,
      input.stageGddProposals
    ),
    firstNotStartedBpTimingProposal: findFirstNotStartedBpTimingProposal(
      input.planId,
      input.blueprintTimingProposals
    ),
    allProposalsResolved: areAllLearnProposalsResolved(
      input.planId,
      input.stageGddProposals,
      input.blueprintTimingProposals
    )
  };
}
