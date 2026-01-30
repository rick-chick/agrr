import { CreateFieldInputDto } from './create-field.dtos';

export interface CreateFieldInputPort {
  execute(dto: CreateFieldInputDto): void;
}