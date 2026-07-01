import { Pesticide } from '../../../domain/pesticides/pesticide';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';

export type PesticideDetailViewState = {
  loading: boolean;
  error: string | null;
  pesticide: Pesticide | null;
  pendingUndoToast: PendingUndoToastRequest | null;
};

export interface PesticideDetailView {
  get control(): PesticideDetailViewState;
  set control(value: PesticideDetailViewState);
  /** Reload detail (e.g. after undo restore). */
  reload(): void;
}