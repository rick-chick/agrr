export type FarmCreateFormData = {
  name: string;
  region: string;
  latitude: number;
  longitude: number;
};

export type FarmCreateViewState = {
  saving: boolean;
  error: string | null;
  formData: FarmCreateFormData;
};

export interface FarmCreateView {
  get control(): FarmCreateViewState;
  set control(value: FarmCreateViewState);
}
