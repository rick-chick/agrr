import { CreatePrivatePlanInputDto } from './create-private-plan.dtos';

export interface CreatePrivatePlanInputPort {
  execute(dto: CreatePrivatePlanInputDto): void;
}