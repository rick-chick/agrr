import { Injectable } from '@angular/core';
import { LoadPrivatePlanFarmsOutputPort } from '../../usecase/private-plan-create/load-private-plan-farms.output-port';
import { PlanNewView } from '../../components/plans/plan-new.view';
import { PrivatePlanFarmsDataDto } from '../../usecase/private-plan-create/load-private-plan-farms.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { isFarmLimitExceededMessage } from '../../domain/farms/farm-create-limit';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class PlanNewPresenter implements LoadPrivatePlanFarmsOutputPort {
  private view: PlanNewView | null = null;

  setView(view: PlanNewView): void {
    this.view = view;
  }

  present(dto: PrivatePlanFarmsDataDto): void {
    if (this.view) {
      const farmLimitBlocked = dto.farms.length === 0 && dto.farmCreateLimitReached;
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: null,
        farms: dto.farms,
        selectedFarmId: null,
        noFieldsWarning: false,
        farmLimitBlocked,
        pendingErrorFlash: null
      };
    }
  }

  onError(dto: ErrorDto): void {
    if (this.view) {
      const farmLimitBlocked = isFarmLimitExceededMessage(dto.message);
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: null,
        farms: [],
        farmLimitBlocked,
        pendingErrorFlash: farmLimitBlocked ? null : pendingErrorFlashFromError(dto)
      };
    }
  }
}
