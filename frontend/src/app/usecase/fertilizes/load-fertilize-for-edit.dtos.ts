import { Fertilize } from '../../domain/fertilizes/fertilize';

export interface LoadFertilizeForEditInputDto {
  fertilizeId: number;
}

export interface LoadFertilizeForEditDataDto {
  fertilize: Fertilize;
}
