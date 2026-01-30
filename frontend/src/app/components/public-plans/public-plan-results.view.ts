import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

export type PublicPlanResultsViewState = {
  loading: boolean;
  error: string | null;
  data: CultivationPlanData | null;
};

export interface PublicPlanResultsView {
  get control(): PublicPlanResultsViewState;
  set control(value: PublicPlanResultsViewState);
}
