import { UpdateFieldInputDto } from './update-field.dtos';

export interface UpdateFieldInputPort {
  execute(dto: UpdateFieldInputDto): void;
}