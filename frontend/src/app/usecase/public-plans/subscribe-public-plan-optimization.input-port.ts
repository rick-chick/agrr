import { SubscribePublicPlanOptimizationInputDto } from './subscribe-public-plan-optimization.dtos';

export interface SubscribePublicPlanOptimizationInputPort {
  execute(dto: SubscribePublicPlanOptimizationInputDto): void;
}
