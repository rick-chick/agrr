import { Injectable } from '@angular/core';
import { LoadPrivatePlanFarmsOutputPort } from '../../usecase/private-plan-create/load-private-plan-farms.output-port';
import { PlanNewView } from '../../components/plans/plan-new.view';
import { PrivatePlanFarmsDataDto } from '../../usecase/private-plan-create/load-private-plan-farms.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class PlanNewPresenter implements LoadPrivatePlanFarmsOutputPort {
  private view: PlanNewView | null = null;

  setView(view: PlanNewView): void {
    this.view = view;
  }

  present(dto: PrivatePlanFarmsDataDto): void {
    if (this.view) {
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: null,
        farms: dto.farms,
        selectedFarmId: null,
        noFieldsWarning: false,
        pendingErrorFlash: null
      };
    }
  }

  onError(dto: ErrorDto): void {
    if (this.view) {
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: null,
        pendingErrorFlash: pendingErrorFlashFromError(dto)
      };
    }
  }
}
