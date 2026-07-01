import { Pesticide } from '../../../domain/pesticides/pesticide';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';

export type PesticideListViewState = {
  loading: boolean;
  error: string | null;
  pesticides: Pesticide[];
  pendingUndoToast: PendingUndoToastRequest | null;
};

export interface PesticideListView {
  get control(): PesticideListViewState;
  set control(value: PesticideListViewState);
}
