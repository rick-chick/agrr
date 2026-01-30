import { LoadPublicPlanFarmsInputDto } from './load-public-plan-farms.dtos';

export interface LoadPublicPlanFarmsInputPort {
  execute(dto: LoadPublicPlanFarmsInputDto): void;
}
