import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import {
  bpTimingProposalProgressKey,
  resolveLearnProposalApplicationStatus,
  stageGddProposalProgressKey
} from './learn-proposal-application-progress';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

export function hasConfirmedLearnProposalsWithoutDismissed(
  planId: number,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): boolean {
  for (const proposal of stageGddProposals) {
    const status = resolveLearnProposalApplicationStatus(
      planId,
      stageGddProposalProgressKey(proposal.cropId, proposal.stageId)
    );
    if (status === 'confirmed' || status === 'applied_pending_confirmation') {
      return true;
    }
  }

  for (const proposal of blueprintTimingProposals) {
    const status = resolveLearnProposalApplicationStatus(
      planId,
      bpTimingProposalProgressKey(proposal.cropId, proposal.category)
    );
    if (status === 'confirmed' || status === 'applied_pending_confirmation') {
      return true;
    }
  }

  return false;
}
