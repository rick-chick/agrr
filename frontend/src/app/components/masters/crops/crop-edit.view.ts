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
};

export interface CropEditView {
  get control(): CropEditViewState;
  set control(value: CropEditViewState);
}
