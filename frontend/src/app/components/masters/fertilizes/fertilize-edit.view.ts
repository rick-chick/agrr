export type FertilizeEditFormData = {
  name: string;
  n: number | null;
  p: number | null;
  k: number | null;
  description: string | null;
  package_size: number | null;
  region: string | null;
};

export type FertilizeEditViewState = {
  loading: boolean;
  saving: boolean;
  error: string | null;
  formData: FertilizeEditFormData;
};

export interface FertilizeEditView {
  get control(): FertilizeEditViewState;
  set control(value: FertilizeEditViewState);
}
