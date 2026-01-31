import { Farm } from '../../domain/farms/farm';
import { Crop } from '../../domain/crops/crop';

export interface LoadPrivatePlanSelectCropContextInputDto {
  farmId: number;
}

export interface PrivatePlanSelectCropContextDataDto {
  farm: Farm;
  totalArea: number;
  crops: Crop[];
}