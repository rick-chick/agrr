import { CreateCropStageInputDto } from './create-crop-stage.dtos';

export interface CreateCropStageInputPort {
  execute(dto: CreateCropStageInputDto): void;
}