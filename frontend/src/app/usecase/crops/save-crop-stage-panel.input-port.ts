import { SaveCropStagePanelInputDto } from './save-crop-stage-panel.dtos';

export interface SaveCropStagePanelInputPort {
  execute(dto: SaveCropStagePanelInputDto): void;
}
