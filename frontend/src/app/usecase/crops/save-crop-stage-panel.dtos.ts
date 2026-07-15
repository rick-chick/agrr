import { Crop, CropStage } from '../../domain/crops/crop';
import {
  UpdateTemperatureRequirementPayload,
  UpdateThermalRequirementPayload
} from './crop-stage-gateway';

export interface SaveCropStagePanelInputDto {
  cropId: number;
  stageId: number;
  stagePatch?: { name?: string };
  temperaturePatch?: UpdateTemperatureRequirementPayload;
  thermalPatch?: UpdateThermalRequirementPayload;
}

export interface SaveCropStagePanelSuccessDto {
  stage: CropStage;
}

export interface SaveCropStagePanelPartialFailureDto {
  crop: Crop;
  stageId: number;
}
