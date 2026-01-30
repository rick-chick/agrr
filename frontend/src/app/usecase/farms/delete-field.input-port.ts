import { DeleteFieldInputDto } from './delete-field.dtos';

export interface DeleteFieldInputPort {
  execute(dto: DeleteFieldInputDto): void;
}