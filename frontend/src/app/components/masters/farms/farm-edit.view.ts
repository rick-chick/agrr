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
};

export interface FarmEditView {
  get control(): FarmEditViewState;
  set control(value: FarmEditViewState);
}
