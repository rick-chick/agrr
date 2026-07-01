import { PlanSummary } from '../../domain/plans/plan-summary';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../core/view-effects/pending-error-flash-view.effects';

export type PlanListViewState = {
  loading: boolean;
  error: string | null;
  plans: PlanSummary[];
  pendingUndoToast: PendingUndoToastRequest | null;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface PlanListView {
  get control(): PlanListViewState;
  set control(value: PlanListViewState);
}
