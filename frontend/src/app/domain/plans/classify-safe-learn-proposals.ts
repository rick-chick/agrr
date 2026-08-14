import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  bpTimingProposalProgressKey,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from './learn-proposal-application-progress';
import { DAYS_VARIANCE_THRESHOLD, GDD_VARIANCE_THRESHOLD } from './plan-variance-thresholds';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

export interface SafeLearnProposals {
  stageGdd: StageGddCalibrationProposal[];
  bpTiming: BlueprintTimingAdjustmentProposal[];
  totalCount: number;
}

export function isSafeStageGddProposal(
  planId: number,
  proposal: StageGddCalibrationProposal
): boolean {
  const status = resolveLearnProposalApplicationStatus(
    planId,
    stageGddProposalProgressKey(proposal.cropId, proposal.stageId)
  );
  if (status !== 'not_started') {
    return false;
  }
  if (proposal.proposedRequiredGdd == null) {
    return false;
  }
  return Math.abs(proposal.averageGddDelta) <= GDD_VARIANCE_THRESHOLD;
}

export function isSafeBlueprintTimingProposal(
  planId: number,
  proposal: BlueprintTimingAdjustmentProposal
): boolean {
  const status = resolveLearnProposalApplicationStatus(
    planId,
    bpTimingProposalProgressKey(proposal.cropId, proposal.category)
  );
  if (status !== 'not_started') {
    return false;
  }
  if ((proposal.proposalBody.task_schedule_blueprints?.length ?? 0) === 0) {
    return false;
  }
  return Math.abs(proposal.averageDeltaDays) <= DAYS_VARIANCE_THRESHOLD;
}

export function collectSafeLearnProposals(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): SafeLearnProposals {
  const stageGdd = stageGddProposals.filter((proposal) =>
    isSafeStageGddProposal(planId, proposal)
  );
  const bpTiming = blueprintTimingProposals.filter((proposal) =>
    isSafeBlueprintTimingProposal(planId, proposal)
  );

  return {
    stageGdd,
    bpTiming,
    totalCount: stageGdd.length + bpTiming.length
  };
}
