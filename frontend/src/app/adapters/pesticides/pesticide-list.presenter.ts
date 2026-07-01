import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PesticideListView } from '../../components/masters/pesticides/pesticide-list.view';
import { LoadPesticideListOutputPort } from '../../usecase/pesticides/load-pesticide-list.output-port';
import { PesticideListDataDto } from '../../usecase/pesticides/load-pesticide-list.dtos';
import { DeletePesticideOutputPort } from '../../usecase/pesticides/delete-pesticide.output-port';
import { DeletePesticideSuccessDto } from '../../usecase/pesticides/delete-pesticide.dtos';
import { FlashMessageService } from '../../services/flash-message.service';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';

@Injectable()
export class PesticideListPresenter implements LoadPesticideListOutputPort, DeletePesticideOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: PesticideListView | null = null;

  setView(view: PesticideListView): void {
    this.view = view;
  }

  present(dto: PesticideListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      pesticides: dto.pesticides,
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

  onSuccess(dto: DeletePesticideSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    const nextControl = {
      ...prev,
      pesticides: prev.pesticides.filter((p) => p.id !== dto.deletedPesticideId),
      pendingUndoToast: null as PendingUndoToastRequest | null
    };
    if (dto.undo && dto.refresh) {
      nextControl.pendingUndoToast = pendingUndoToastFromDeletion(dto.undo, dto.refresh);
    }
    this.view.control = nextControl;
  }
}
