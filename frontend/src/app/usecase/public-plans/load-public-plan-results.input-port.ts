import { LoadPublicPlanResultsInputDto } from './load-public-plan-results.dtos';

export interface LoadPublicPlanResultsInputPort {
  execute(dto: LoadPublicPlanResultsInputDto): void;
}
