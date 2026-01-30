import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

export interface LoadPublicPlanResultsInputDto {
  planId: number;
}

export interface PublicPlanResultsDataDto {
  data: CultivationPlanData;
}
