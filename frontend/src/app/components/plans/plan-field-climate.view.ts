import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import {
  FieldClimateLatestImplementation,
  FieldClimateWorkDayMarker
} from '../../domain/plans/field-climate-work-records';

export type PlanFieldClimateViewState = {
  loading: boolean;
  error: string | null;
  climateData: FieldCultivationClimateData | null;
  workDayMarkers: FieldClimateWorkDayMarker[];
  latestImplementation: FieldClimateLatestImplementation | null;
};

export interface PlanFieldClimateView {
  get control(): PlanFieldClimateViewState;
  set control(value: PlanFieldClimateViewState);
}
