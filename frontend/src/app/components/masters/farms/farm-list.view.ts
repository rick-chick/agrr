import { Farm } from '../../../domain/farms/farm';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';

export type FarmListViewState = {
  loading: boolean;
  error: string | null;
  farms: Farm[];
  pendingUndoToast: PendingUndoToastRequest | null;
  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface FarmListView {
  get control(): FarmListViewState;
  set control(value: FarmListViewState);
}
