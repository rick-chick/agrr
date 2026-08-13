import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';

export interface LoadPlanDetailInputDto {
  planId: number;
}

export interface PlanDetailDataDto {
  plan: PlanSummary;
  planData: CultivationPlanData;
  varianceActionItemsOnGantt: PlanVarianceActionItem[];
}
