import { Fertilize } from '../../../domain/fertilizes/fertilize';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';

export type FertilizeDetailViewState = {
  loading: boolean;
  error: string | null;
  fertilize: Fertilize | null;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface FertilizeDetailView {
  get control(): FertilizeDetailViewState;
  set control(value: FertilizeDetailViewState);
}
