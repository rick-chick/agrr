import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
export type FertilizeCreateFormData = {
  name: string;
  n: number | null;
  p: number | null;
  k: number | null;
  description: string | null;
  package_size: number | null;
  region: string | null;
};

export type FertilizeCreateViewState = {
  saving: boolean;
  error: string | null;
  formData: FertilizeCreateFormData;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface FertilizeCreateView {
  get control(): FertilizeCreateViewState;
  set control(value: FertilizeCreateViewState);
}
