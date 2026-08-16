import type { BlueprintAmountAdjustmentProposalRaw } from './blueprint-amount-adjustment-proposal';
import type { BlueprintTimingAdjustmentProposalRaw } from './blueprint-timing-adjustment-proposal';
import type { PlanVarianceLearningSnapshot } from './plan-variance-learning-snapshot';
import type { PlanVsActualSummary } from './plan-vs-actual-summary';
import type { StageGddCalibrationProposalRaw } from './stage-gdd-calibration-proposal';

export interface LearnProposalRawSources {
  stageGddCalibrationProposals: StageGddCalibrationProposalRaw[];
  blueprintTimingAdjustmentProposals: BlueprintTimingAdjustmentProposalRaw[];
  blueprintAmountAdjustmentProposals: BlueprintAmountAdjustmentProposalRaw[];
}

function stageGddKey(proposal: StageGddCalibrationProposalRaw): string {
  return `${proposal.crop_id}:${proposal.stage_order}`;
}

function blueprintKey(proposal: BlueprintTimingAdjustmentProposalRaw): string {
  return `${proposal.crop_id}:${proposal.category}`;
}

function blueprintAmountKey(proposal: BlueprintAmountAdjustmentProposalRaw): string {
  return `${proposal.crop_id}:${proposal.category}:${proposal.task_type}`;
}

export function collectLearnProposalRawSources(
  varianceSummary: PlanVsActualSummary | null,
  learningSnapshot: PlanVarianceLearningSnapshot | null
): LearnProposalRawSources {
  const stageGddByKey = new Map<string, StageGddCalibrationProposalRaw>();
  const blueprintByKey = new Map<string, BlueprintTimingAdjustmentProposalRaw>();
  const blueprintAmountByKey = new Map<string, BlueprintAmountAdjustmentProposalRaw>();

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
    for (const proposal of summary.blueprint_amount_adjustment_proposals ?? []) {
      blueprintAmountByKey.set(blueprintAmountKey(proposal), proposal);
    }
  };

  appendFromSummary(learningSnapshot?.summary);
  appendFromSummary(varianceSummary);

  return {
    stageGddCalibrationProposals: [...stageGddByKey.values()],
    blueprintTimingAdjustmentProposals: [...blueprintByKey.values()],
    blueprintAmountAdjustmentProposals: [...blueprintAmountByKey.values()]
  };
}
