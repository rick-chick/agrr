import { ResetPublicPlanCreationStateInputDto } from './reset-public-plan-creation-state.dtos';

export interface ResetPublicPlanCreationStateInputPort {
  execute(dto: ResetPublicPlanCreationStateInputDto): void;
}
