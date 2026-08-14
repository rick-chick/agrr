import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  bpTimingProposalProgressKey,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from './learn-proposal-application-progress';
import { DAYS_VARIANCE_THRESHOLD, GDD_VARIANCE_THRESHOLD } from './plan-variance-thresholds';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

interface SafeLearnProposals {
  stageGdd: StageGddCalibrationProposal[];
  bpTiming: BlueprintTimingAdjustmentProposal[];
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

export function isSafeBpTimingProposal(
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
  if (!proposal.proposalBody) {
    return false;
  }
  return Math.abs(proposal.averageDeltaDays) <= DAYS_VARIANCE_THRESHOLD;
}

export function collectSafeLearnProposals(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): SafeLearnProposals {
  return {
    stageGdd: stageGddProposals.filter((proposal) => isSafeStageGddProposal(planId, proposal)),
    bpTiming: blueprintTimingProposals.filter((proposal) =>
      isSafeBpTimingProposal(planId, proposal)
    )
  };
}

export function countSafeLearnProposals(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): number {
  const safe = collectSafeLearnProposals(planId, stageGddProposals, blueprintTimingProposals);
  return safe.stageGdd.length + safe.bpTiming.length;
}
