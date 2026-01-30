import { Farm } from '../../domain/farms/farm';

export interface LoadFarmForEditInputDto {
  farmId: number;
}

export interface LoadFarmForEditDataDto {
  farm: Farm;
}
