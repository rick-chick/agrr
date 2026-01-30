import { SubscribePlanOptimizationInputDto } from './subscribe-plan-optimization.dtos';

export interface SubscribePlanOptimizationInputPort {
  execute(dto: SubscribePlanOptimizationInputDto): void;
}
