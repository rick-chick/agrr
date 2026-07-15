import { ReorderCropStagesInputDto } from './reorder-crop-stages.dtos';
import { CropStage } from '../../domain/crops/crop';

export interface ReorderCropStagesInputPort {
  execute(dto: ReorderCropStagesInputDto): void;
}

export interface ReorderCropStagesOutputDto {
  stages: CropStage[];
}

export interface ReorderCropStagesOutputPort {
  present(dto: ReorderCropStagesOutputDto): void;
  onError(error: { message: string }): void;
}

export const REORDER_CROP_STAGES_OUTPUT_PORT = 'REORDER_CROP_STAGES_OUTPUT_PORT';
