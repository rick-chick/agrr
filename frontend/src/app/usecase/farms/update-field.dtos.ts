import { Field } from '../../domain/farms/field';

export interface UpdateFieldInputDto {
  fieldId: number;
  payload: {
    name: string;
    area: number | null;
    daily_fixed_cost: number | null;
    region: string | null;
  };
}

export interface UpdateFieldOutputDto {
  field: Field;
}