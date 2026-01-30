import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';

export interface LoadPlanDetailInputDto {
  planId: number;
}

export interface PlanDetailDataDto {
  plan: PlanSummary;
  planData: CultivationPlanData;
}
