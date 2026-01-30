import { Crop } from '../../domain/crops/crop';

export interface LoadCropDetailInputDto {
  cropId: number;
}

export interface CropDetailDataDto {
  crop: Crop;
}
