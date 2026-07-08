import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
export type PesticideCreateFormData = {
  name: string;
  active_ingredient: string | null;
  description: string | null;
  crop_id: number;
  pest_id: number;
  region: string | null;
};

export type PesticideCreateViewState = {
  saving: boolean;
  error: string | null;
  formData: PesticideCreateFormData;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface PesticideCreateView {
  get control(): PesticideCreateViewState;
  set control(value: PesticideCreateViewState);
}