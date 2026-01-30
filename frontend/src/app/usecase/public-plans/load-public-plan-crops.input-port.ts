import { LoadPublicPlanCropsInputDto } from './load-public-plan-crops.dtos';

export interface LoadPublicPlanCropsInputPort {
  execute(dto: LoadPublicPlanCropsInputDto): void;
}
