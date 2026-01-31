import { UpdateCropStageInputDto } from './update-crop-stage.dtos';

export interface UpdateCropStageInputPort {
  execute(dto: UpdateCropStageInputDto): void;
}