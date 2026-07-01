import { FarmPlanCreateOption } from '../../usecase/private-plan-create/private-plan-create-gateway';
import { PendingErrorFlashRequest } from '../../core/view-effects/pending-error-flash-view.effects';
import { PendingSuccessFlashRequest } from '../../core/view-effects/pending-success-flash-view.effects';

export interface PlanNewViewState {
  loading: boolean;
  submitting: boolean;
  error: string | null;
  farms: FarmPlanCreateOption[];
  selectedFarmId: number | null;
  noFieldsWarning: boolean;
  pendingErrorFlash: PendingErrorFlashRequest | null;
  pendingSuccessFlash: PendingSuccessFlashRequest | null;
}

export interface PlanNewView {
  control: PlanNewViewState;
}
