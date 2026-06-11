import { FarmPlanCreateOption } from '../../usecase/private-plan-create/private-plan-create-gateway';

export interface PlanNewViewState {
  loading: boolean;
  submitting: boolean;
  error: string | null;
  farms: FarmPlanCreateOption[];
  selectedFarmId: number | null;
  noFieldsWarning: boolean;
}

export interface PlanNewView {
  control: PlanNewViewState;
}
