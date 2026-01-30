import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PestDetailView } from '../../components/masters/pests/pest-detail.view';
import { LoadPestDetailOutputPort } from '../../usecase/pests/load-pest-detail.output-port';
import { PestDetailDataDto } from '../../usecase/pests/load-pest-detail.dtos';
import { DeletePestOutputPort } from '../../usecase/pests/delete-pest.output-port';
import { DeletePestSuccessDto } from '../../usecase/pests/delete-pest.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class PestDetailPresenter implements LoadPestDetailOutputPort, DeletePestOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private view: PestDetailView | null = null;

  setView(view: PestDetailView): void {
    this.view = view;
  }

  present(dto: PestDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      pest: dto.pest
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      loading: false,
      error: null,
      pest: null
    };
  }

  onSuccess(dto: DeletePestSuccessDto): void {
    if (dto.undo) {
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        () => this.view?.reload()
      );
    }
  }
}