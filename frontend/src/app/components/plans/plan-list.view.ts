import { PlanListPlan } from '../../domain/plans/plan-list-plan';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../core/view-effects/pending-error-flash-view.effects';

export type PlanListViewState = {
  loading: boolean;
  error: string | null;
  plans: PlanListPlan[];
  pendingUndoToast: PendingUndoToastRequest | null;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface PlanListView {
  get control(): PlanListViewState;
  set control(value: PlanListViewState);
}
