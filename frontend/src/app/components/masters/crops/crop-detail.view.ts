import { Crop } from '../../../domain/crops/crop';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';

export type CropDetailViewState = {
  loading: boolean;
  error: string | null;
  crop: Crop | null;
  pendingUndoToast: PendingUndoToastRequest | null;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface CropDetailView {
  get control(): CropDetailViewState;
  set control(value: CropDetailViewState);
  /** Reload detail (e.g. after undo restore). */
  reload(): void;
}
