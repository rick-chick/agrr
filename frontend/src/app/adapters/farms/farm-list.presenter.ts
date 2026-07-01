import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FarmListView } from '../../components/masters/farms/farm-list.view';
import { LoadFarmListOutputPort } from '../../usecase/farms/load-farm-list.output-port';
import { FarmListDataDto } from '../../usecase/farms/load-farm-list.dtos';
import { DeleteFarmOutputPort } from '../../usecase/farms/delete-farm.output-port';
import { DeleteFarmSuccessDto } from '../../usecase/farms/delete-farm.dtos';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class FarmListPresenter implements LoadFarmListOutputPort, DeleteFarmOutputPort {
  private view: FarmListView | null = null;

  setView(view: FarmListView): void {
    this.view = view;
  }

  present(dto: FarmListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      farms: dto.farms,
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      pendingErrorFlash: pendingErrorFlashFromError(dto)
    };
  }

  onSuccess(dto: DeleteFarmSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    const nextControl = {
      ...prev,
      farms: prev.farms.filter((f) => f.id !== dto.deletedFarmId),
      pendingUndoToast: null as PendingUndoToastRequest | null
    };
    if (dto.undo && dto.refresh) {
      nextControl.pendingUndoToast = pendingUndoToastFromDeletion(dto.undo, dto.refresh);
    }
    this.view.control = nextControl;
  }
}
