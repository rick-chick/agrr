import { Farm } from '../../domain/farms/farm';
import { Field } from '../../domain/farms/field';

export interface LoadFarmDetailInputDto {
  farmId: number;
}

export interface FarmDetailDataDto {
  farm: Farm;
  fields: Field[];
}
