import { PlanSummary } from '../../domain/plans/plan-summary';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';

export type PlanListViewState = {
  loading: boolean;
  error: string | null;
  plans: PlanSummary[];
  pendingUndoToast: PendingUndoToastRequest | null;
};

export interface PlanListView {
  get control(): PlanListViewState;
  set control(value: PlanListViewState);
}
