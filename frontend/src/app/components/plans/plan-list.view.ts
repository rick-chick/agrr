import { PlanSummary } from '../../domain/plans/plan-summary';

export type PlanListViewState = {
  loading: boolean;
  error: string | null;
  plans: PlanSummary[];
};

export interface PlanListView {
  get control(): PlanListViewState;
  set control(value: PlanListViewState);
}
