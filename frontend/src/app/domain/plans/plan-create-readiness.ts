import {
  blueprintGenerationReadiness,
  type BlueprintGenerationReadiness
} from '../crops/blueprint-generation-readiness';
import type { Crop } from '../crops/crop';
import type { CropTaskScheduleBlueprint } from '../crops/crop-task-schedule-blueprint';
import type { Farm } from '../farms/farm';

export interface PlanCreateCropReadiness {
  cropId: number;
  name: string;
  readiness: BlueprintGenerationReadiness;
  ready: boolean;
}

export interface PlanCreateReadiness {
  farmId: number;
  fieldCount: number;
  fieldsReady: boolean;
  weatherReady: boolean;
  weatherStatus: Farm['weather_data_status'];
  cropsReady: boolean;
  cropSummaries: PlanCreateCropReadiness[];
  allReady: boolean;
}

export interface PlanCreateReadinessInput {
  farmId: number;
  fieldCount: number;
  hasValidFields: boolean;
  weatherStatus: Farm['weather_data_status'];
  crops: Crop[];
  cropBlueprints: Record<number, CropTaskScheduleBlueprint[]>;
}

export function isWeatherReady(status: Farm['weather_data_status']): boolean {
  return status === 'completed';
}

export function buildPlanCreateReadiness(input: PlanCreateReadinessInput): PlanCreateReadiness {
  const fieldsReady = input.hasValidFields && input.fieldCount > 0;
  const weatherReady = isWeatherReady(input.weatherStatus);

  const userCrops = input.crops.filter((crop) => !crop.is_reference);
  const cropSummaries: PlanCreateCropReadiness[] = userCrops.map((crop) => {
    const blueprints = input.cropBlueprints[crop.id] ?? [];
    const readiness = blueprintGenerationReadiness(crop, blueprints);
    return {
      cropId: crop.id,
      name: crop.name,
      readiness,
      ready: readiness.ready
    };
  });

  const cropsReady = cropSummaries.some((summary) => summary.ready);

  return {
    farmId: input.farmId,
    fieldCount: input.fieldCount,
    fieldsReady,
    weatherReady,
    weatherStatus: input.weatherStatus,
    cropsReady,
    cropSummaries,
    allReady: fieldsReady && weatherReady && cropsReady
  };
}
