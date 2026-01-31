import { CropStage } from '../../domain/crops/crop';

export type CropEditFormData = {
  name: string;
  variety: string | null;
  area_per_unit: number | null;
  revenue_per_area: number | null;
  region: string | null;
  groups: string[];
  groupsDisplay: string;
  is_reference: boolean;
  crop_stages: CropStage[];
};

export type CropEditViewState = {
  loading: boolean;
  saving: boolean;
  error: string | null;
  formData: CropEditFormData;
};

export interface CropEditView {
  get control(): CropEditViewState;
  set control(value: CropEditViewState);
}
