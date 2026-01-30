import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PesticideListView } from '../../components/masters/pesticides/pesticide-list.view';
import { LoadPesticideListOutputPort } from '../../usecase/pesticides/load-pesticide-list.output-port';
import { PesticideListDataDto } from '../../usecase/pesticides/load-pesticide-list.dtos';
import { DeletePesticideOutputPort } from '../../usecase/pesticides/delete-pesticide.output-port';
import { DeletePesticideSuccessDto } from '../../usecase/pesticides/delete-pesticide.dtos';
import { UndoToastService } from '../../services/undo-toast.service';

@Injectable()
export class PesticideListPresenter implements LoadPesticideListOutputPort, DeletePesticideOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private view: PesticideListView | null = null;

  setView(view: PesticideListView): void {
    this.view = view;
  }

  present(dto: PesticideListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      pesticides: dto.pesticides
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      pesticides: []
    };
  }

  onSuccess(dto: DeletePesticideSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    this.view.control = {
      ...prev,
      pesticides: prev.pesticides.filter((p) => p.id !== dto.deletedPesticideId)
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
