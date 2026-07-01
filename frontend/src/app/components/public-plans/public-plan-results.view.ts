import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PendingErrorFlashRequest } from '../../core/view-effects/pending-error-flash-view.effects';
import { PendingSuccessFlashRequest } from '../../core/view-effects/pending-success-flash-view.effects';
import { PendingNavigationRequest } from '../../core/view-effects/pending-navigation-view.effects';

export type PublicPlanResultsViewState = {
  loading: boolean;
  error: string | null;
  data: CultivationPlanData | null;

  pendingErrorFlash: PendingErrorFlashRequest | null;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
  pendingNavigation: PendingNavigationRequest | null;
};

export interface PublicPlanResultsView {
  get control(): PublicPlanResultsViewState;
  set control(value: PublicPlanResultsViewState);
}
