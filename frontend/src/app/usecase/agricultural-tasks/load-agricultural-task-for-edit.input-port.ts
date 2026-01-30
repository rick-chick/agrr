import { LoadAgriculturalTaskForEditInputDto } from './load-agricultural-task-for-edit.dtos';

export interface LoadAgriculturalTaskForEditInputPort {
  execute(dto: LoadAgriculturalTaskForEditInputDto): void;
}