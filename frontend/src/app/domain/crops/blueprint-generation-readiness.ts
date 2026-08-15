import type { Crop, CropStage } from './crop';
import type { CropTaskScheduleBlueprint } from './crop-task-schedule-blueprint';

const FIELD_WORK_TASK_TYPE = 'field_work';
const BASAL_FERTILIZATION_TASK_TYPE = 'basal_fertilization';
const TOPDRESS_FERTILIZATION_TASK_TYPE = 'topdress_fertilization';

export interface BlueprintGenerationReadiness {
  hasFieldWorkBlueprint: boolean;
  hasFertilizerBlueprint: boolean;
  fieldWorkBlueprintsReady: boolean;
  fertilizerBlueprintsReady: boolean;
  blueprintsReady: boolean;
  stageRequirementsReady: boolean;
  ready: boolean;
}

export function defaultBlueprintReadiness(): BlueprintGenerationReadiness {
  return {
    hasFieldWorkBlueprint: false,
    hasFertilizerBlueprint: false,
    fieldWorkBlueprintsReady: false,
    fertilizerBlueprintsReady: false,
    blueprintsReady: false,
    stageRequirementsReady: false,
    ready: false
  };
}

export function blueprintGenerationReadiness(
  crop: Crop | null | undefined,
  blueprints: CropTaskScheduleBlueprint[]
): BlueprintGenerationReadiness {
  const hasFieldWorkBlueprint = blueprints.some(
    (blueprint) => blueprint.task_type === FIELD_WORK_TASK_TYPE
  );
  const hasFertilizerBlueprint = blueprints.some(
    (blueprint) =>
      blueprint.task_type === BASAL_FERTILIZATION_TASK_TYPE ||
      blueprint.task_type === TOPDRESS_FERTILIZATION_TASK_TYPE
  );
  const fieldWorkBlueprintsReady = hasFieldWorkBlueprint || hasFertilizerBlueprint;
  const fertilizerBlueprintsReady = hasFertilizerBlueprint;
  const blueprintsReady = fieldWorkBlueprintsReady && fertilizerBlueprintsReady;
  const stageRequirementsReady = hasCompleteStageRequirements(crop);
  return {
    hasFieldWorkBlueprint,
    hasFertilizerBlueprint,
    fieldWorkBlueprintsReady,
    fertilizerBlueprintsReady,
    blueprintsReady,
    stageRequirementsReady,
    ready: blueprintsReady && stageRequirementsReady
  };
}

export function stageRequirementsComplete(stage: CropStage): boolean {
  const baseTemperature = stage.temperature_requirement?.base_temperature;
  const requiredGdd = stage.thermal_requirement?.required_gdd;
  return baseTemperature != null && requiredGdd != null && requiredGdd > 0;
}

export function stageMissingBaseTemperature(stage: CropStage): boolean {
  return stage.temperature_requirement?.base_temperature == null;
}

export function stageMissingRequiredGdd(stage: CropStage): boolean {
  const requiredGdd = stage.thermal_requirement?.required_gdd;
  return requiredGdd == null || requiredGdd <= 0;
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
