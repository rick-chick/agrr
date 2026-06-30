import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';

export interface WorkHubViewState {
  loading: boolean;
  submitting: boolean;
  error: string | null;
  farms: WorkHubFarmRow[];
}

export interface WorkHubView {
  control: WorkHubViewState;
}
