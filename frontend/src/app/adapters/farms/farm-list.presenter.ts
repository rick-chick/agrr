import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FarmListView } from '../../components/masters/farms/farm-list.view';
import { LoadFarmListOutputPort } from '../../usecase/farms/load-farm-list.output-port';
import { FarmListDataDto } from '../../usecase/farms/load-farm-list.dtos';
import { DeleteFarmOutputPort } from '../../usecase/farms/delete-farm.output-port';
import { DeleteFarmSuccessDto } from '../../usecase/farms/delete-farm.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class FarmListPresenter implements LoadFarmListOutputPort, DeleteFarmOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private view: FarmListView | null = null;

  setView(view: FarmListView): void {
    this.view = view;
  }

  present(dto: FarmListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      farms: dto.farms
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

  onSuccess(dto: DeleteFarmSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    this.view.control = {
      ...prev,
      farms: prev.farms.filter((f) => f.id !== dto.deletedFarmId)
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
