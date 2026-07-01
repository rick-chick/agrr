import { Pest } from '../../../domain/pests/pest';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';

export type PestListViewState = {
  loading: boolean;
  error: string | null;
  pests: Pest[];
  pendingUndoToast: PendingUndoToastRequest | null;
};

export interface PestListView {
  get control(): PestListViewState;
  set control(value: PestListViewState);
}
