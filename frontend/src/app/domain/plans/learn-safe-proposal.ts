import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  bpTimingProposalProgressKey,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from './learn-proposal-application-progress';
import {
  DAYS_VARIANCE_THRESHOLD,
  GDD_VARIANCE_THRESHOLD
} from './plan-variance-thresholds';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

export function isSafeStageGddProposal(proposal: StageGddCalibrationProposal): boolean {
  return (
    proposal.proposedRequiredGdd != null &&
    Math.abs(proposal.averageGddDelta) <= GDD_VARIANCE_THRESHOLD
  );
}

export function isSafeBpTimingProposal(proposal: BlueprintTimingAdjustmentProposal): boolean {
  return Math.abs(proposal.averageDeltaDays) <= DAYS_VARIANCE_THRESHOLD;
}

export function filterSafeStageGddProposals(
  proposals: ReadonlyArray<StageGddCalibrationProposal>
): StageGddCalibrationProposal[] {
  return proposals.filter(isSafeStageGddProposal);
}

export function filterSafeBpTimingProposals(
  proposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): BlueprintTimingAdjustmentProposal[] {
  return proposals.filter(isSafeBpTimingProposal);
}

export function filterBulkApplicableStageGddProposals(
  planId: number,
  proposals: ReadonlyArray<StageGddCalibrationProposal>
): StageGddCalibrationProposal[] {
  return filterSafeStageGddProposals(proposals).filter(
    (proposal) =>
      resolveLearnProposalApplicationStatus(
        planId,
        stageGddProposalProgressKey(proposal.cropId, proposal.stageId)
      ) === 'not_started'
  );
}

export function filterBulkApplicableBpTimingProposals(
  planId: number,
  proposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): BlueprintTimingAdjustmentProposal[] {
  return filterSafeBpTimingProposals(proposals).filter(
    (proposal) =>
      resolveLearnProposalApplicationStatus(
        planId,
        bpTimingProposalProgressKey(proposal.cropId, proposal.category)
      ) === 'not_started'
  );
}

export function countBulkApplicableLearnProposals(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): number {
  return (
    filterBulkApplicableStageGddProposals(planId, stageGddProposals).length +
    filterBulkApplicableBpTimingProposals(planId, blueprintTimingProposals).length
  );
}

export function countSafeLearnProposals(
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): number {
  return (
    filterSafeStageGddProposals(stageGddProposals).length +
    filterSafeBpTimingProposals(blueprintTimingProposals).length
  );
}
