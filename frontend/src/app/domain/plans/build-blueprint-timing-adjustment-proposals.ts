import type { CropTaskScheduleBlueprint } from '../crops/crop-task-schedule-blueprint';
import type { CropSetupProposalBody } from '../crops/crop-setup-proposal';
import {
  BLUEPRINT_TIMING_PATCH_INTENT,
  type BlueprintTimingAdjustmentProposal,
  type BlueprintTimingAdjustmentProposalRaw
} from './blueprint-timing-adjustment-proposal';

const CATEGORY_TASK_TYPES: Record<string, readonly string[]> = {
  general: ['field_work'],
  fertilizer: ['basal_fertilization', 'topdress_fertilization']
};

export function buildBlueprintTimingAdjustmentProposals(
  rawProposals: ReadonlyArray<BlueprintTimingAdjustmentProposalRaw>,
  blueprintsByCropId: ReadonlyMap<number, ReadonlyArray<CropTaskScheduleBlueprint>>
): BlueprintTimingAdjustmentProposal[] {
  const proposals: BlueprintTimingAdjustmentProposal[] = [];

  for (const raw of rawProposals) {
    const taskTypes = CATEGORY_TASK_TYPES[raw.category] ?? [];
    if (taskTypes.length === 0) {
      continue;
    }

    const blueprints = (blueprintsByCropId.get(raw.crop_id) ?? []).filter((blueprint) =>
      taskTypes.includes(blueprint.task_type)
    );
    if (blueprints.length === 0) {
      continue;
    }

    const gddOffset = resolveGddOffset(raw);
    if (gddOffset == null || Math.abs(gddOffset) < 0.05) {
      continue;
    }

    const patches = blueprints
      .map((blueprint) => {
        const currentGdd = blueprint.gdd_trigger;
        if (currentGdd == null) {
          return null;
        }
        const proposedGdd = roundGdd(currentGdd + gddOffset);
        if (proposedGdd <= 0) {
          return null;
        }
        return {
          blueprint_id: blueprint.id,
          gdd_trigger: proposedGdd
        };
      })
      .filter((patch): patch is { blueprint_id: number; gdd_trigger: number } => patch != null);

    if (patches.length === 0) {
      continue;
    }

    const proposalBody: CropSetupProposalBody = {
      intent: BLUEPRINT_TIMING_PATCH_INTENT,
      stages: [],
      agricultural_tasks: [],
      task_schedule_blueprints: patches
    };

    proposals.push({
      cropId: raw.crop_id,
      cropName: raw.crop_name,
      category: raw.category,
      averageDeltaDays: raw.average_delta_days,
      averageGddDelta: raw.average_gdd_delta,
      recordedItemCount: raw.recorded_item_count,
      affectedBlueprintCount: patches.length,
      proposalBody
    });
  }

  return proposals.sort(
    (left, right) =>
      Math.abs(right.averageDeltaDays) - Math.abs(left.averageDeltaDays) ||
      left.cropId - right.cropId ||
      left.category.localeCompare(right.category)
  );
}

function resolveGddOffset(raw: BlueprintTimingAdjustmentProposalRaw): number | null {
  if (raw.average_gdd_delta != null) {
    return raw.average_gdd_delta;
  }
  return raw.average_delta_days;
}

function roundGdd(value: number): number {
  return Math.round(value * 10) / 10;
}
