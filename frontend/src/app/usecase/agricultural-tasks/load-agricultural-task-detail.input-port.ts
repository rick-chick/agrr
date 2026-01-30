import { LoadAgriculturalTaskDetailInputDto } from './load-agricultural-task-detail.dtos';

export interface LoadAgriculturalTaskDetailInputPort {
  execute(dto: LoadAgriculturalTaskDetailInputDto): void;
}