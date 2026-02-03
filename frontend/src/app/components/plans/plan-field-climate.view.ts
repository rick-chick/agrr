import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';

export type PlanFieldClimateViewState = {
  loading: boolean;
  error: string | null;
  climateData: FieldCultivationClimateData | null;
};

export interface PlanFieldClimateView {
  get control(): PlanFieldClimateViewState;
  set control(value: PlanFieldClimateViewState);
}
