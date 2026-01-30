export type PesticideEditFormData = {
  name: string;
  active_ingredient: string | null;
  description: string | null;
  crop_id: number;
  pest_id: number;
  region: string | null;
};

export type PesticideEditViewState = {
  loading: boolean;
  saving: boolean;
  error: string | null;
  formData: PesticideEditFormData;
};

export interface PesticideEditView {
  get control(): PesticideEditViewState;
  set control(value: PesticideEditViewState);
}