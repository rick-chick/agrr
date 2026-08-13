import type { CropStage } from '../crops/crop';
import type {
  StageGddCalibrationProposal,
  StageGddCalibrationProposalRaw
} from './stage-gdd-calibration-proposal';

export function buildStageGddCalibrationProposals(
  rawProposals: ReadonlyArray<StageGddCalibrationProposalRaw>,
  cropStagesByCropId: ReadonlyMap<number, ReadonlyArray<CropStage>>
): StageGddCalibrationProposal[] {
  const proposals: StageGddCalibrationProposal[] = [];

  for (const raw of rawProposals) {
    const stages = cropStagesByCropId.get(raw.crop_id) ?? [];
    const stage = stages.find((entry) => entry.order === raw.stage_order);
    if (!stage) {
      continue;
    }

    const currentRequiredGdd = stage.thermal_requirement?.required_gdd ?? null;
    const proposedRequiredGdd =
      currentRequiredGdd != null
        ? roundGdd(currentRequiredGdd + raw.average_gdd_delta)
        : null;

    if (proposedRequiredGdd == null || Math.abs(raw.average_gdd_delta) < 0.05) {
      continue;
    }

    proposals.push({
      cropId: raw.crop_id,
      cropName: raw.crop_name,
      stageId: stage.id,
      stageOrder: raw.stage_order,
      stageName: raw.stage_name,
      averageGddDelta: raw.average_gdd_delta,
      recordedItemCount: raw.recorded_item_count,
      currentRequiredGdd,
      proposedRequiredGdd
    });
  }

  return proposals.sort(
    (left, right) =>
      Math.abs(right.averageGddDelta) - Math.abs(left.averageGddDelta) ||
      left.cropId - right.cropId ||
      left.stageOrder - right.stageOrder
  );
}

function roundGdd(value: number): number {
  return Math.round(value * 10) / 10;
}
