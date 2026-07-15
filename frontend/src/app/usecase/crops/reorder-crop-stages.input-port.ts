import { ReorderCropStagesInputDto } from './reorder-crop-stages.dtos';

export interface ReorderCropStagesInputPort {
  execute(dto: ReorderCropStagesInputDto): void;
}
