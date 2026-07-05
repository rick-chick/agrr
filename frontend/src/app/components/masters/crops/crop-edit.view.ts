import { PendingErrorFlashRequest } from '../../../core/view-effects/pending-error-flash-view.effects';
import { PendingSuccessFlashRequest } from '../../../core/view-effects/pending-success-flash-view.effects';

export type CropEditFormData = {
  name: string;
  variety: string | null;
  area_per_unit: number | null;
  revenue_per_area: number | null;
  region: string | null;
  groups: string[];
  groupsDisplay: string;
  is_reference: boolean;
};

export type CropEditViewState = {
  loading: boolean;
  saving: boolean;
  error: string | null;
  formData: CropEditFormData;

  pendingErrorFlash: PendingErrorFlashRequest | null;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
};

export interface CropEditView {
  get control(): CropEditViewState;
  set control(value: CropEditViewState);
}
