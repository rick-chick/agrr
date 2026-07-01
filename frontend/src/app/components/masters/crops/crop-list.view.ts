import { Crop } from '../../../domain/crops/crop';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';

export type CropListViewState = {
  loading: boolean;
  error: string | null;
  crops: Crop[];
  pendingUndoToast: PendingUndoToastRequest | null;
};

export interface CropListView {
  get control(): CropListViewState;
  set control(value: CropListViewState);
}
