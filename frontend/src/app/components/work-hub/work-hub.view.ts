import { PendingSuccessFlashRequest } from '../../core/view-effects/pending-success-flash-view.effects';
import { PendingNavigationRequest } from '../../core/view-effects/pending-navigation-view.effects';
import type { CrossFarmScheduleFilter, CrossFarmScheduleRow } from '../../domain/work-schedule/cross-farm-schedule-row';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';

export interface WorkHubViewState {
  loading: boolean;
  submitting: boolean;
  error: string | null;
  farms: WorkHubFarmRow[];
  scheduleLoading: boolean;
  scheduleError: string | null;
  scheduleRows: CrossFarmScheduleRow[];
  scheduleFilter: CrossFarmScheduleFilter;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
  pendingNavigation: PendingNavigationRequest | null;
}

export interface WorkHubView {
  control: WorkHubViewState;
}
