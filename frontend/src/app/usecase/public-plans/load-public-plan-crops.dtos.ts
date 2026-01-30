import { Crop } from '../../domain/crops/crop';

export interface LoadPublicPlanCropsInputDto {
  farmId: number;
}

export interface PublicPlanCropsDataDto {
  crops: Crop[];
}
