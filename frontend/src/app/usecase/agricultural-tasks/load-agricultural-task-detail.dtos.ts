import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';

export interface LoadAgriculturalTaskDetailInputDto {
  agriculturalTaskId: number;
}

export interface LoadAgriculturalTaskDetailDataDto {
  agriculturalTask: AgriculturalTask;
}