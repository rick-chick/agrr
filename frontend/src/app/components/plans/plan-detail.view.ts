import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';

export type PlanDetailViewState = {
  loading: boolean;
  error: string | null;
  plan: PlanSummary | null;
  planData: CultivationPlanData | null;
};

export interface PlanDetailView {
  get control(): PlanDetailViewState;
  set control(value: PlanDetailViewState);
}
