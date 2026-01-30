import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FertilizeListView } from '../../components/masters/fertilizes/fertilize-list.view';
import { LoadFertilizeListOutputPort } from '../../usecase/fertilizes/load-fertilize-list.output-port';
import { FertilizeListDataDto } from '../../usecase/fertilizes/load-fertilize-list.dtos';
import { DeleteFertilizeOutputPort } from '../../usecase/fertilizes/delete-fertilize.output-port';
import { DeleteFertilizeSuccessDto } from '../../usecase/fertilizes/delete-fertilize.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class FertilizeListPresenter
  implements LoadFertilizeListOutputPort, DeleteFertilizeOutputPort
{
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private view: FertilizeListView | null = null;

  setView(view: FertilizeListView): void {
    this.view = view;
  }

  present(dto: FertilizeListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      fertilizes: dto.fertilizes
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

  onSuccess(dto: DeleteFertilizeSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    this.view.control = {
      ...prev,
      fertilizes: prev.fertilizes.filter((f) => f.id !== dto.deletedFertilizeId)
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
