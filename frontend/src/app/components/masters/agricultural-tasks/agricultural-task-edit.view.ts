import { AgriculturalTaskCreateFormData } from './agricultural-task-create.view';

export type AgriculturalTaskEditFormData = AgriculturalTaskCreateFormData;

export type AgriculturalTaskEditViewState = {
  loading: boolean;
  saving: boolean;
  error: string | null;
  formData: AgriculturalTaskEditFormData;
};

export interface AgriculturalTaskEditView {
  get control(): AgriculturalTaskEditViewState;
  set control(value: AgriculturalTaskEditViewState);
}