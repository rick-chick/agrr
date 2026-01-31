import { DeleteCropStageInputDto } from './delete-crop-stage.dtos';

export interface DeleteCropStageInputPort {
  execute(dto: DeleteCropStageInputDto): void;
}