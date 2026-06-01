import { Farm } from '../../domain/farms/farm';

export interface PublicPlanCreateViewState {
  loading: boolean;
  error: string | null;
  farms: Farm[];
}

export interface PublicPlanCreateView {
  control: PublicPlanCreateViewState;
}
