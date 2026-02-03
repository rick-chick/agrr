import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PlanListView } from '../../components/plans/plan-list.view';
import { LoadPlanListOutputPort } from '../../usecase/plans/load-plan-list.output-port';
import { PlanListDataDto } from '../../usecase/plans/load-plan-list.dtos';
import { DeletePlanOutputPort } from '../../usecase/plans/delete-plan.output-port';
import { DeletePlanSuccessDto } from '../../usecase/plans/delete-plan.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class PlanListPresenter implements LoadPlanListOutputPort, DeletePlanOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
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
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.scope === 'load-plan-list' ? dto.message : null
    };
  }

  onSuccess(dto: DeletePlanSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    this.view.control = {
      ...prev,
      plans: prev.plans.filter((plan) => plan.id !== dto.deletedPlanId)
    };
    if (dto.undo) {
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        dto.refresh
      );
    }
  }
}
