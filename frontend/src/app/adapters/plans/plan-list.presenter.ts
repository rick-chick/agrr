import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanListView } from '../../components/plans/plan-list.view';
import { LoadPlanListOutputPort } from '../../usecase/plans/load-plan-list.output-port';
import { PlanListDataDto } from '../../usecase/plans/load-plan-list.dtos';

@Injectable()
export class PlanListPresenter implements LoadPlanListOutputPort {
  private view: PlanListView | null = null;

  setView(view: PlanListView): void {
    this.view = view;
  }

  present(dto: PlanListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      plans: dto.plans
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      plans: []
    };
  }
}
