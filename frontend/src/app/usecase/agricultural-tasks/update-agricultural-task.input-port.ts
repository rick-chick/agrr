import { UpdateAgriculturalTaskInputDto } from './update-agricultural-task.dtos';

export interface UpdateAgriculturalTaskInputPort {
  execute(dto: UpdateAgriculturalTaskInputDto): void;
}