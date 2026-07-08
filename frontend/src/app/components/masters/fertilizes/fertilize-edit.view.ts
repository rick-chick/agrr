import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
export type FertilizeEditFormData = {
  name: string;
  n: number | null;
  p: number | null;
  k: number | null;
  description: string | null;
  package_size: number | null;
  region: string | null;
};

export type FertilizeEditViewState = {
  loading: boolean;
  saving: boolean;
  error: string | null;
  formData: FertilizeEditFormData;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface FertilizeEditView {
  get control(): FertilizeEditViewState;
  set control(value: FertilizeEditViewState);
}
