import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanListView } from '../../components/plans/plan-list.view';
import { LoadPlanListOutputPort } from '../../usecase/plans/load-plan-list.output-port';
import { PlanListDataDto } from '../../usecase/plans/load-plan-list.dtos';
import { DeletePlanOutputPort } from '../../usecase/plans/delete-plan.output-port';
import { DeletePlanSuccessDto } from '../../usecase/plans/delete-plan.dtos';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class PlanListPresenter implements LoadPlanListOutputPort, DeletePlanOutputPort {
  private view: PlanListView | null = null;

  setView(view: PlanListView): void {
    this.view = view;
  }

  present(dto: PlanListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      plans: dto.plans,
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.scope === 'load-plan-list' ? dto.message : null,
      pendingErrorFlash: pendingErrorFlashFromError(dto)
    };
  }

  onSuccess(dto: DeletePlanSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    const nextControl = {
      ...prev,
      plans: prev.plans.filter((plan) => plan.id !== dto.deletedPlanId),
      pendingUndoToast: null as PendingUndoToastRequest | null
    };
    if (dto.undo) {
      nextControl.pendingUndoToast = pendingUndoToastFromDeletion(dto.undo, dto.refresh);
    }
    this.view.control = nextControl;
  }
}
