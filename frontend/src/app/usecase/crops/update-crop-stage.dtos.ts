import { CropStage } from '../../domain/crops/crop';

export interface UpdateCropStageInputDto {
  cropId: number;
  stageId: number;
  payload: {
    name?: string;
    order?: number;
  };
}

export interface UpdateCropStageOutputDto {
  stage: CropStage;
}