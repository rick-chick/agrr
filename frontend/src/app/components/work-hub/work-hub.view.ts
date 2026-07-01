import { PendingSuccessFlashRequest } from '../../core/view-effects/pending-success-flash-view.effects';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';

export interface WorkHubViewState {
  loading: boolean;
  submitting: boolean;
  error: string | null;
  farms: WorkHubFarmRow[];
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
}

export interface WorkHubView {
  control: WorkHubViewState;
}
