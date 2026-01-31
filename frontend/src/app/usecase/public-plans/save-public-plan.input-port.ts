import { SavePublicPlanInputDto } from './save-public-plan.dtos';

export interface SavePublicPlanInputPort {
  execute(dto: SavePublicPlanInputDto): void;
}