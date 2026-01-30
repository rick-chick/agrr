import { CreateAgriculturalTaskInputDto } from './create-agricultural-task.dtos';

export interface CreateAgriculturalTaskInputPort {
  execute(dto: CreateAgriculturalTaskInputDto): void;
}