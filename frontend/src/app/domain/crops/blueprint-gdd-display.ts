import type { BlueprintGddValidationError } from './blueprint-gdd-validation';
import { blueprintGddValidationError } from './blueprint-gdd-validation';
import type { BlueprintStageLane } from './blueprint-stage-grouping';
import type { CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

export function gddValueForBlueprint(
  blueprint: CropTaskScheduleBlueprint,
  drafts: Record<number, number | null>
): number | null {
  const draft = drafts[blueprint.id];
  return draft !== undefined ? draft : blueprint.gdd_trigger;
}

export function blueprintGddErrorsForDrafts(
  stages: CropStage[],
  blueprints: CropTaskScheduleBlueprint[],
  drafts: Record<number, number | null>
): Record<number, BlueprintGddValidationError | null> {
  const errors: Record<number, BlueprintGddValidationError | null> = {};
  for (const blueprint of blueprints) {
    errors[blueprint.id] = blueprintGddValidationError(
      stages,
      blueprint.stage_order,
      gddValueForBlueprint(blueprint, drafts)
    );
  }
  return errors;
}

export function blueprintLaneOutOfRangeCounts(
  stages: CropStage[],
  lanes: BlueprintStageLane[],
  drafts: Record<number, number | null>
): Record<number, number> {
  const counts: Record<number, number> = {};
  for (const lane of lanes) {
    if (lane.stageOrder == null) {
      continue;
    }
    let count = 0;
    for (const blueprint of lane.blueprints) {
      const error = blueprintGddValidationError(
        stages,
        blueprint.stage_order,
        gddValueForBlueprint(blueprint, drafts)
      );
      if (error === 'out_of_range' || error === 'missing_stage') {
        count += 1;
      }
    }
    if (count > 0) {
      counts[lane.stageOrder] = count;
    }
  }
  return counts;
}
