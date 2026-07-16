import type { Crop, CropStage } from './crop';
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

export function stageRequirementsComplete(stage: CropStage): boolean {
  const baseTemperature = stage.temperature_requirement?.base_temperature;
  const requiredGdd = stage.thermal_requirement?.required_gdd;
  return baseTemperature != null && requiredGdd != null;
}

export function stageMissingBaseTemperature(stage: CropStage): boolean {
  return stage.temperature_requirement?.base_temperature == null;
}

export function stageMissingRequiredGdd(stage: CropStage): boolean {
  return stage.thermal_requirement?.required_gdd == null;
}

export interface StageRequirementGap {
  stageId: number;
  stageName: string;
  missingBaseTemperature: boolean;
  missingRequiredGdd: boolean;
}

export function stageRequirementGaps(stages: CropStage[]): StageRequirementGap[] {
  return stages
    .filter((stage) => !stageRequirementsComplete(stage))
    .map((stage) => ({
      stageId: stage.id,
      stageName: stage.name,
      missingBaseTemperature: stageMissingBaseTemperature(stage),
      missingRequiredGdd: stageMissingRequiredGdd(stage)
    }));
}

function hasCompleteStageRequirements(crop: Crop | null | undefined): boolean {
  const stages = crop?.crop_stages ?? [];
  if (stages.length === 0) {
    return false;
  }
  return stages.every(stageRequirementsComplete);
}
