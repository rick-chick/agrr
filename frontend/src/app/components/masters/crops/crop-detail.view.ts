import { Crop } from '../../../domain/crops/crop';
import { BlueprintGenerationReadiness } from '../../../domain/crops/blueprint-generation-readiness';
import { PendingUndoToastRequest } from '../../../core/view-effects/pending-undo-toast-view.effects';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
import { PendingSuccessFlashRequest } from '../../../core/view-effects/pending-success-flash-view.effects';

export type CropDetailViewState = {
  loading: boolean;
  error: string | null;
  crop: Crop | null;
  pendingUndoToast: PendingUndoToastRequest | null;
  pendingErrorFlash: PendingErrorFlashRequest | null;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;

  blueprintsLoading: boolean;
  blueprintCount: number;
  blueprintReadiness: BlueprintGenerationReadiness;
};

export interface CropDetailView {
  get control(): CropDetailViewState;
  set control(value: CropDetailViewState);
  reload(): void;
}
