import { AgriculturalTask } from '../../../domain/agricultural-tasks/agricultural-task';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';

export type AgriculturalTaskDetailViewState = {
  loading: boolean;
  error: string | null;
  agriculturalTask: AgriculturalTask | null;
  pendingUndoToast: PendingUndoToastRequest | null;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface AgriculturalTaskDetailView {
  get control(): AgriculturalTaskDetailViewState;
  set control(value: AgriculturalTaskDetailViewState);
  /** Reload detail (e.g. after undo restore). */
  reload(): void;
}