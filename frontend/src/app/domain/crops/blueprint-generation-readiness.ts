import type { Crop } from './crop';
import type { MastersCropTaskTemplate } from './masters-crop-task-template';

export interface BlueprintGenerationReadiness {
  templatesReady: boolean;
  stageRequirementsReady: boolean;
  ready: boolean;
}

export function blueprintGenerationReadiness(
  crop: Crop | null | undefined,
  templates: MastersCropTaskTemplate[]
): BlueprintGenerationReadiness {
  const templatesReady = templates.length >= 1;
  const stageRequirementsReady = hasCompleteStageRequirements(crop);
  return {
    templatesReady,
    stageRequirementsReady,
    ready: templatesReady && stageRequirementsReady
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
