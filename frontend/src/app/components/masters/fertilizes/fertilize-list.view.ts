import { Fertilize } from '../../../domain/fertilizes/fertilize';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';

export type FertilizeListViewState = {
  loading: boolean;
  error: string | null;
  fertilizes: Fertilize[];
  pendingUndoToast: PendingUndoToastRequest | null;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface FertilizeListView {
  get control(): FertilizeListViewState;
  set control(value: FertilizeListViewState);
}
