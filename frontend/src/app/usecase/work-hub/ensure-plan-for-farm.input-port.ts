import { EnsurePlanForFarmInputDto } from './ensure-plan-for-farm.dtos';

export interface EnsurePlanForFarmInputPort {
  execute(dto: EnsurePlanForFarmInputDto): void;
}
