import { Crop, CropStage } from '../../domain/crops/crop';
import {
  UpdateNutrientRequirementPayload,
  UpdateSunshineRequirementPayload,
  UpdateTemperatureRequirementPayload
} from './crop-stage-gateway';

export interface SaveCropStageAdvancedDetailsInputDto {
  cropId: number;
  stageId: number;
  sunshinePatch?: UpdateSunshineRequirementPayload;
  nutrientPatch?: UpdateNutrientRequirementPayload;
  temperaturePatch?: UpdateTemperatureRequirementPayload;
}

export interface SaveCropStageAdvancedDetailsSuccessDto {
  stage: CropStage;
}

export interface SaveCropStageAdvancedDetailsPartialFailureDto {
  crop: Crop;
  stageId: number;
}
