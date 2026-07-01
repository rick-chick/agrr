import { Pest } from '../../../domain/pests/pest';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';

export type PestDetailViewState = {
  loading: boolean;
  error: string | null;
  pest: Pest | null;
  pendingUndoToast: PendingUndoToastRequest | null;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface PestDetailView {
  get control(): PestDetailViewState;
  set control(value: PestDetailViewState);
  /** Reload detail (e.g. after undo restore). */
  reload(): void;
}