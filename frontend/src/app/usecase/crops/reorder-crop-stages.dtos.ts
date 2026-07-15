import { CropStage } from '../../domain/crops/crop';

export interface ReorderCropStagesInputDto {
  cropId: number;
  entries: Array<{ id: number; order: number }>;
}

export interface ReorderCropStagesOutputDto {
  stages: CropStage[];
}
