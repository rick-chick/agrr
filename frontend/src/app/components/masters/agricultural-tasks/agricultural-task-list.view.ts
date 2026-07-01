import { AgriculturalTask } from '../../../domain/agricultural-tasks/agricultural-task';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';

export type AgriculturalTaskListViewState = {
  loading: boolean;
  error: string | null;
  tasks: AgriculturalTask[];
  pendingUndoToast: PendingUndoToastRequest | null;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface AgriculturalTaskListView {
  get control(): AgriculturalTaskListViewState;
  set control(value: AgriculturalTaskListViewState);
}
