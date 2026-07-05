import type { Crop } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

export interface BlueprintGenerationReadiness {
  blueprintsReady: boolean;
  stageRequirementsReady: boolean;
  ready: boolean;
}

export function blueprintGenerationReadiness(
  crop: Crop | null | undefined,
  blueprints: CropTaskScheduleBlueprint[]
): BlueprintGenerationReadiness {
  const blueprintsReady = blueprints.length >= 1;
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
