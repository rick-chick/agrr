export type PestEditFormData = {
  name: string;
  name_scientific: string | null;
  family: string | null;
  order: string | null;
  description: string | null;
  occurrence_season: string | null;
  region: string | null;
};

export type PestEditViewState = {
  loading: boolean;
  saving: boolean;
  error: string | null;
  formData: PestEditFormData;
};

export interface PestEditView {
  get control(): PestEditViewState;
  set control(value: PestEditViewState);
}