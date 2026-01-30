export type FertilizeCreateFormData = {
  name: string;
  n: number | null;
  p: number | null;
  k: number | null;
  description: string | null;
  package_size: number | null;
  region: string | null;
};

export type FertilizeCreateViewState = {
  saving: boolean;
  error: string | null;
  formData: FertilizeCreateFormData;
};

export interface FertilizeCreateView {
  get control(): FertilizeCreateViewState;
  set control(value: FertilizeCreateViewState);
}
