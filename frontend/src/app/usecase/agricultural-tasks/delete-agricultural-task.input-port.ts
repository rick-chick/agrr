import { DeleteAgriculturalTaskInputDto } from './delete-agricultural-task.dtos';

export interface DeleteAgriculturalTaskInputPort {
  execute(dto: DeleteAgriculturalTaskInputDto): void;
}