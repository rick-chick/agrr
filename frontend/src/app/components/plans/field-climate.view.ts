import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';

export type FieldClimateViewState = {
  loading: boolean;
  error: string | null;
  data: FieldCultivationClimateData | null;
};

export interface FieldClimateView {
  get control(): FieldClimateViewState;
  set control(value: FieldClimateViewState);
}
