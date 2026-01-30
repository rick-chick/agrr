import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanDetailView } from '../../components/plans/plan-detail.view';
import { LoadPlanDetailOutputPort } from '../../usecase/plans/load-plan-detail.output-port';
import { PlanDetailDataDto } from '../../usecase/plans/load-plan-detail.dtos';

@Injectable()
export class PlanDetailPresenter implements LoadPlanDetailOutputPort {
  private view: PlanDetailView | null = null;

  setView(view: PlanDetailView): void {
    this.view = view;
  }

  present(dto: PlanDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      plan: dto.plan,
      planData: dto.planData
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      plan: null,
      planData: null
    };
  }
}
