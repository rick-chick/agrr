import { Injectable, inject } from '@angular/core';
import { LoadPrivatePlanFarmsOutputPort } from '../../usecase/private-plan-create/load-private-plan-farms.output-port';
import { PlanNewView } from '../../components/plans/plan-new.view';
import { PrivatePlanFarmsDataDto } from '../../usecase/private-plan-create/load-private-plan-farms.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class PlanNewPresenter implements LoadPrivatePlanFarmsOutputPort {
  private view: PlanNewView | null = null;

  setView(view: PlanNewView): void {
    this.view = view;
  }

  present(dto: PrivatePlanFarmsDataDto): void {
    if (this.view) {
      this.view.control = {
        loading: false,
        error: null,
        farms: dto.farms
      };
    }
  }

  onError(dto: ErrorDto): void {
    if (this.view) {
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: dto.message
      };
    }
  }
}