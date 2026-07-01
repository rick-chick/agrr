import { PendingSuccessFlashRequest } from '../../core/view-effects/pending-success-flash-view.effects';
import { PendingNavigationRequest } from '../../core/view-effects/pending-navigation-view.effects';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';

export interface WorkHubViewState {
  loading: boolean;
  submitting: boolean;
  error: string | null;
  farms: WorkHubFarmRow[];
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
  pendingNavigation: PendingNavigationRequest | null;
}

export interface WorkHubView {
  control: WorkHubViewState;
}
