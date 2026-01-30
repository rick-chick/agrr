import { Field } from '../../domain/farms/field';

export interface CreateFieldInputDto {
  farmId: number;
  payload: {
    name: string;
    area: number | null;
    daily_fixed_cost: number | null;
    region: string | null;
  };
}

export interface CreateFieldOutputDto {
  field: Field;
  farmId: number;
}