import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { AgriculturalTaskListView } from '../../components/masters/agricultural-tasks/agricultural-task-list.view';
import { LoadAgriculturalTaskListOutputPort } from '../../usecase/agricultural-tasks/load-agricultural-task-list.output-port';
import { AgriculturalTaskListDataDto } from '../../usecase/agricultural-tasks/load-agricultural-task-list.dtos';
import { DeleteAgriculturalTaskOutputPort } from '../../usecase/agricultural-tasks/delete-agricultural-task.output-port';
import { DeleteAgriculturalTaskSuccessDto } from '../../usecase/agricultural-tasks/delete-agricultural-task.dtos';
import { FlashMessageService } from '../../services/flash-message.service';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';

@Injectable()
export class AgriculturalTaskListPresenter implements LoadAgriculturalTaskListOutputPort, DeleteAgriculturalTaskOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: AgriculturalTaskListView | null = null;

  setView(view: AgriculturalTaskListView): void {
    this.view = view;
  }

  present(dto: AgriculturalTaskListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      tasks: dto.tasks,
      pendingUndoToast: null
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null
    };
  }

  onSuccess(dto: DeleteAgriculturalTaskSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    const nextControl = {
      ...prev,
      tasks: prev.tasks.filter((t) => t.id !== dto.deletedAgriculturalTaskId),
      pendingUndoToast: null as PendingUndoToastRequest | null
    };
    if (dto.undo && dto.refresh) {
      nextControl.pendingUndoToast = pendingUndoToastFromDeletion(dto.undo, dto.refresh);
    }
    this.view.control = nextControl;
  }
}
