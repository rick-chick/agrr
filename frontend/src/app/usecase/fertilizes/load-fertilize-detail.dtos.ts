import { Fertilize } from '../../domain/fertilizes/fertilize';

export interface LoadFertilizeDetailInputDto {
  fertilizeId: number;
}

export interface FertilizeDetailDataDto {
  fertilize: Fertilize;
}
