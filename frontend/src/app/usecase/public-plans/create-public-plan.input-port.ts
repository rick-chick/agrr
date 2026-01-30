import { CreatePublicPlanInputDto } from './create-public-plan.dtos';

export interface CreatePublicPlanInputPort {
  execute(dto: CreatePublicPlanInputDto): void;
}
