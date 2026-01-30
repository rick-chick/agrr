import { Crop } from '../../domain/crops/crop';

export interface LoadCropForEditInputDto {
  cropId: number;
}

export interface LoadCropForEditDataDto {
  crop: Crop;
}
