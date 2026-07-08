import { AgriculturalTaskCreateFormData } from './agricultural-task-create.view';
import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';

export type AgriculturalTaskEditFormData = AgriculturalTaskCreateFormData;

export type AgriculturalTaskEditViewState = {
  loading: boolean;
  saving: boolean;
  error: string | null;
  formData: AgriculturalTaskEditFormData;

  pendingErrorFlash: PendingErrorFlashRequest | null;
};

export interface AgriculturalTaskEditView {
  get control(): AgriculturalTaskEditViewState;
  set control(value: AgriculturalTaskEditViewState);
}