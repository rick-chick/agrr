import { PreviewWorkRowMiniClimateInputDto } from './preview-work-row-mini-climate.dtos';

export interface PreviewWorkRowMiniClimateInputPort {
  execute(dto: PreviewWorkRowMiniClimateInputDto): void;
}
