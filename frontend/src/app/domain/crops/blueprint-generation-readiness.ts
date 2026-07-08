import type { Crop } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

const FIELD_WORK_TASK_TYPE = 'field_work';

export interface BlueprintGenerationReadiness {
  blueprintsReady: boolean;
  stageRequirementsReady: boolean;
  ready: boolean;
}

export function defaultBlueprintReadiness(): BlueprintGenerationReadiness {
  return {
    blueprintsReady: false,
    stageRequirementsReady: false,
    ready: false
  };
}

export function blueprintGenerationReadiness(
  crop: Crop | null | undefined,
  blueprints: CropTaskScheduleBlueprint[]
): BlueprintGenerationReadiness {
  const blueprintsReady = blueprints.some(
    (blueprint) => blueprint.task_type === FIELD_WORK_TASK_TYPE
  );
  const stageRequirementsReady = hasCompleteStageRequirements(crop);
  return {
    blueprintsReady,
    stageRequirementsReady,
    ready: blueprintsReady && stageRequirementsReady
  };
}

function hasCompleteStageRequirements(crop: Crop | null | undefined): boolean {
  const stages = crop?.crop_stages ?? [];
  return stages.some((stage) => {
    const baseTemperature = stage.temperature_requirement?.base_temperature;
    const requiredGdd = stage.thermal_requirement?.required_gdd;
    return baseTemperature != null && requiredGdd != null;
  });
}
