import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import type { UnifiedLearnProposalQueueItem } from './build-unified-learn-proposal-queue';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

export type LearnQueueItemInlineApplyMode = 'stage_gdd' | 'bp_timing' | 'detail_edit_only';

export function findStageGddProposalForQueueItem(
  item: UnifiedLearnProposalQueueItem,
  proposals: ReadonlyArray<StageGddCalibrationProposal>
): StageGddCalibrationProposal | null {
  if (item.kind !== 'stage_gdd') {
    return null;
  }
  const [, cropId, stageId] = item.id.split(':');
  return (
    proposals.find(
      (proposal) =>
        String(proposal.cropId) === cropId && String(proposal.stageId) === stageId
    ) ?? null
  );
}

export function findBpTimingProposalForQueueItem(
  item: UnifiedLearnProposalQueueItem,
  proposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): BlueprintTimingAdjustmentProposal | null {
  if (item.kind !== 'bp_timing') {
    return null;
  }
  const [, cropId, category] = item.id.split(':');
  return (
    proposals.find(
      (proposal) => String(proposal.cropId) === cropId && proposal.category === category
    ) ?? null
  );
}

export function resolveLearnQueueItemInlineApplyMode(
  item: UnifiedLearnProposalQueueItem,
  stageGddProposals: ReadonlyArray<StageGddCalibrationProposal>,
  blueprintTimingProposals: ReadonlyArray<BlueprintTimingAdjustmentProposal>
): LearnQueueItemInlineApplyMode | null {
  if (item.category !== 'requires_confirmation') {
    return null;
  }

  if (item.kind === 'stage_gdd') {
    const proposal = findStageGddProposalForQueueItem(item, stageGddProposals);
    if (!proposal) {
      return null;
    }
    return proposal.proposedRequiredGdd != null ? 'stage_gdd' : 'detail_edit_only';
  }

  if (item.kind === 'bp_timing') {
    const proposal = findBpTimingProposalForQueueItem(item, blueprintTimingProposals);
    if (!proposal) {
      return null;
    }
    const hasBlueprints = (proposal.proposalBody.task_schedule_blueprints?.length ?? 0) > 0;
    return hasBlueprints ? 'bp_timing' : 'detail_edit_only';
  }

  return null;
}
