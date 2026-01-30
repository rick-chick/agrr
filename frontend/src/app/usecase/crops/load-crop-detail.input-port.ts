import { LoadCropDetailInputDto } from './load-crop-detail.dtos';

export interface LoadCropDetailInputPort {
  execute(dto: LoadCropDetailInputDto): void;
}
