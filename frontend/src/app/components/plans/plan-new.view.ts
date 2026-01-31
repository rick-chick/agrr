import { Farm } from '../../domain/farms/farm';

export interface PlanNewViewState {
  loading: boolean;
  error: string | null;
  farms: Farm[];
}

export interface PlanNewView {
  control: PlanNewViewState;
}