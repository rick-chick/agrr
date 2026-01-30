import { LoadPlanDetailInputDto } from './load-plan-detail.dtos';

export interface LoadPlanDetailInputPort {
  execute(dto: LoadPlanDetailInputDto): void;
}
