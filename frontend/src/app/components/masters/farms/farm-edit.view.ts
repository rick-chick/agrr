import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
export type FarmEditFormData = {
  name: string;
  region: string;
  latitude: number;
  longitude: number;
};

export type FarmEditViewState = {
  loading: boolean;
  saving: boolean;
  error: string | null;
  formData: FarmEditFormData;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface FarmEditView {
  get control(): FarmEditViewState;
  set control(value: FarmEditViewState);
}
