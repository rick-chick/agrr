import type { BlueprintTimingAdjustmentProposal } from './blueprint-timing-adjustment-proposal';
import type { LearnProposalRawSources } from './collect-learn-proposal-raw-sources';
import type { StageGddCalibrationProposal } from './stage-gdd-calibration-proposal';

export function mapLearnProposalRawSourcesToPhaseProposals(
  sources: LearnProposalRawSources
): {
  stageGddProposals: StageGddCalibrationProposal[];
  blueprintTimingProposals: BlueprintTimingAdjustmentProposal[];
} {
  return {
    stageGddProposals: sources.stageGddCalibrationProposals.map((proposal) => ({
      cropId: proposal.crop_id,
      cropName: proposal.crop_name,
      stageId: proposal.stage_order,
      stageOrder: proposal.stage_order,
      stageName: proposal.stage_name,
      averageGddDelta: proposal.average_gdd_delta,
      recordedItemCount: proposal.recorded_item_count,
      currentRequiredGdd: null,
      proposedRequiredGdd: null
    })),
    blueprintTimingProposals: sources.blueprintTimingAdjustmentProposals.map((proposal) => ({
      cropId: proposal.crop_id,
      cropName: proposal.crop_name,
      category: proposal.category,
      averageDeltaDays: proposal.average_delta_days,
      averageGddDelta: proposal.average_gdd_delta,
      recordedItemCount: proposal.recorded_item_count,
      affectedBlueprintCount: 0,
      proposalBody: {
        stages: [],
        agricultural_tasks: [],
        task_schedule_blueprints: []
      }
    }))
  };
}
