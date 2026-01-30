export type PestCreateFormData = {
  name: string;
  name_scientific: string | null;
  family: string | null;
  order: string | null;
  description: string | null;
  occurrence_season: string | null;
  region: string | null;
};

export type PestCreateViewState = {
  saving: boolean;
  error: string | null;
  formData: PestCreateFormData;
};

export interface PestCreateView {
  get control(): PestCreateViewState;
  set control(value: PestCreateViewState);
}