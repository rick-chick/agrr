export type CropCreateFormData = {
  name: string;
  variety: string | null;
  area_per_unit: number | null;
  revenue_per_area: number | null;
  region: string | null;
  groups: string[];
  groupsDisplay: string;
  is_reference: boolean;
};

export type CropCreateViewState = {
  saving: boolean;
  error: string | null;
  formData: CropCreateFormData;
};

export interface CropCreateView {
  get control(): CropCreateViewState;
  set control(value: CropCreateViewState);
}
