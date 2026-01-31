import { CropStage } from '../../domain/crops/crop';

export interface CreateCropStageInputDto {
  cropId: number;
  payload: {
    name: string;
    order: number;
  };
}

export interface CreateCropStageOutputDto {
  stage: CropStage;
}