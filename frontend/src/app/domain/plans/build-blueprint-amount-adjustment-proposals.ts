import type { CropTaskScheduleBlueprint } from '../crops/crop-task-schedule-blueprint';
import type { CropSetupProposalBody } from '../crops/crop-setup-proposal';
import {
  BLUEPRINT_AMOUNT_PATCH_INTENT,
  type BlueprintAmountAdjustmentProposal,
  type BlueprintAmountAdjustmentProposalRaw
} from './blueprint-amount-adjustment-proposal';

export function buildBlueprintAmountAdjustmentProposals(
  rawProposals: ReadonlyArray<BlueprintAmountAdjustmentProposalRaw>,
  blueprintsByCropId: ReadonlyMap<number, ReadonlyArray<CropTaskScheduleBlueprint>>
): BlueprintAmountAdjustmentProposal[] {
  const proposals: BlueprintAmountAdjustmentProposal[] = [];

  for (const raw of rawProposals) {
    const blueprints = (blueprintsByCropId.get(raw.crop_id) ?? []).filter(
      (blueprint) => blueprint.task_type === raw.task_type
    );
    if (blueprints.length === 0) {
      continue;
    }

    const patches = blueprints
      .map((blueprint) => {
        const currentAmount = blueprint.amount;
        if (currentAmount == null) {
          return null;
        }
        const proposedAmount = roundAmount(currentAmount + raw.average_amount_delta);
        if (proposedAmount <= 0) {
          return null;
        }
        return {
          blueprint_id: blueprint.id,
          amount: proposedAmount,
          amount_unit: raw.amount_unit ?? blueprint.amount_unit
        };
      })
      .filter(
        (patch): patch is { blueprint_id: number; amount: number; amount_unit: string | null } =>
          patch != null
      );

    if (patches.length === 0) {
      continue;
    }

    const proposalBody: CropSetupProposalBody = {
      intent: BLUEPRINT_AMOUNT_PATCH_INTENT,
      stages: [],
      agricultural_tasks: [],
      task_schedule_blueprints: patches
    };

    proposals.push({
      cropId: raw.crop_id,
      cropName: raw.crop_name,
      category: raw.category,
      taskType: raw.task_type,
      stageOrder: raw.stage_order,
      stageName: raw.stage_name,
      averageAmountDelta: raw.average_amount_delta,
      recordedItemCount: raw.recorded_item_count,
      amountUnit: raw.amount_unit,
      affectedBlueprintCount: patches.length,
      proposalBody
    });
  }

  return proposals.sort(
    (left, right) =>
      Math.abs(right.averageAmountDelta) - Math.abs(left.averageAmountDelta) ||
      left.cropId - right.cropId ||
      left.category.localeCompare(right.category) ||
      left.taskType.localeCompare(right.taskType)
  );
}

function roundAmount(value: number): number {
  return Math.round(value * 100) / 100;
}
