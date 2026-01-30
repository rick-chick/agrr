import { AgriculturalTask } from '../../domain/agricultural-tasks/agricultural-task';

export interface LoadAgriculturalTaskForEditInputDto {
  agriculturalTaskId: number;
}

export interface LoadAgriculturalTaskForEditDataDto {
  agriculturalTask: AgriculturalTask;
}