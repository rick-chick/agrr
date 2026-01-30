import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PestListView } from '../../components/masters/pests/pest-list.view';
import { LoadPestListOutputPort } from '../../usecase/pests/load-pest-list.output-port';
import { PestListDataDto } from '../../usecase/pests/load-pest-list.dtos';
import { DeletePestOutputPort } from '../../usecase/pests/delete-pest.output-port';
import { DeletePestSuccessDto } from '../../usecase/pests/delete-pest.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class PestListPresenter implements LoadPestListOutputPort, DeletePestOutputPort {
  private readonly undoToast = inject(UndoToastService);
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
      pests: dto.pests
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
    this.view.control = {
      ...prev,
      pests: prev.pests.filter((p) => p.id !== dto.deletedPestId)
    };
    if (dto.undo && dto.refresh) {
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        dto.refresh
      );
    }
  }
}
