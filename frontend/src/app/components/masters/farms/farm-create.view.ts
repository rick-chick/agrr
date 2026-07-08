import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
export type FarmCreateFormData = {
  name: string;
  region: string;
  latitude: number;
  longitude: number;
};

export type FarmCreateViewState = {
  saving: boolean;
  error: string | null;
  formData: FarmCreateFormData;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface FarmCreateView {
  get control(): FarmCreateViewState;
  set control(value: FarmCreateViewState);
}
