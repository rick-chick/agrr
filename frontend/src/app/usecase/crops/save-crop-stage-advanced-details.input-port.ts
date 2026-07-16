import { SaveCropStageAdvancedDetailsInputDto } from './save-crop-stage-advanced-details.dtos';

export interface SaveCropStageAdvancedDetailsInputPort {
  execute(dto: SaveCropStageAdvancedDetailsInputDto): void;
}
