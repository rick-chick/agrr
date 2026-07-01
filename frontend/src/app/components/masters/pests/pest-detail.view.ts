import { Pest } from '../../../domain/pests/pest';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';

export type PestDetailViewState = {
  loading: boolean;
  error: string | null;
  pest: Pest | null;
  pendingUndoToast: PendingUndoToastRequest | null;
};

export interface PestDetailView {
  get control(): PestDetailViewState;
  set control(value: PestDetailViewState);
  /** Reload detail (e.g. after undo restore). */
  reload(): void;
}