import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PestListView } from '../../components/masters/pests/pest-list.view';
import { LoadPestListOutputPort } from '../../usecase/pests/load-pest-list.output-port';
import { PestListDataDto } from '../../usecase/pests/load-pest-list.dtos';
import { DeletePestOutputPort } from '../../usecase/pests/delete-pest.output-port';
import { DeletePestSuccessDto } from '../../usecase/pests/delete-pest.dtos';
import { FlashMessageService } from '../../services/flash-message.service';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';

@Injectable()
export class PestListPresenter implements LoadPestListOutputPort, DeletePestOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: PestListView | null = null;

  setView(view: PestListView): void {
    this.view = view;
  }

  present(dto: PestListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      pests: dto.pests,
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

  onSuccess(dto: DeletePestSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    const nextControl = {
      ...prev,
      pests: prev.pests.filter((p) => p.id !== dto.deletedPestId),
      pendingUndoToast: null as PendingUndoToastRequest | null
    };
    if (dto.undo && dto.refresh) {
      nextControl.pendingUndoToast = pendingUndoToastFromDeletion(dto.undo, dto.refresh);
    }
    this.view.control = nextControl;
  }
}
