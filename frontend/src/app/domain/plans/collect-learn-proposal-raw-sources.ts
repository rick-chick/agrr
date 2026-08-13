import type { BlueprintTimingAdjustmentProposalRaw } from './blueprint-timing-adjustment-proposal';
import type { PlanVarianceLearningSnapshot } from './plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';
import type { StageGddCalibrationProposalRaw } from './stage-gdd-calibration-proposal';

export interface LearnProposalRawSources {
  stageGddCalibrationProposals: StageGddCalibrationProposalRaw[];
  blueprintTimingAdjustmentProposals: BlueprintTimingAdjustmentProposalRaw[];
}

function stageGddKey(proposal: StageGddCalibrationProposalRaw): string {
  return `${proposal.crop_id}:${proposal.stage_order}`;
}

function blueprintKey(proposal: BlueprintTimingAdjustmentProposalRaw): string {
  return `${proposal.crop_id}:${proposal.category}`;
}

export function collectLearnProposalRawSources(
  varianceSummary: PlanVsActualSummary | null,
  learningSnapshot: PlanVarianceLearningSnapshot | null
): LearnProposalRawSources {
  const stageGddByKey = new Map<string, StageGddCalibrationProposalRaw>();
  const blueprintByKey = new Map<string, BlueprintTimingAdjustmentProposalRaw>();

  const appendFromSummary = (summary: PlanVsActualSummary | null | undefined) => {
    if (!summary) {
      return;
    }
    for (const proposal of summary.stage_gdd_calibration_proposals ?? []) {
      stageGddByKey.set(stageGddKey(proposal), proposal);
    }
    for (const proposal of summary.blueprint_timing_adjustment_proposals ?? []) {
      blueprintByKey.set(blueprintKey(proposal), proposal);
    }
  };

  appendFromSummary(learningSnapshot?.summary);
  appendFromSummary(varianceSummary);

  return {
    stageGddCalibrationProposals: [...stageGddByKey.values()],
    blueprintTimingAdjustmentProposals: [...blueprintByKey.values()]
  };
}
