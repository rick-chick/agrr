import { Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PesticideDetailView } from '../../components/masters/pesticides/pesticide-detail.view';
import { LoadPesticideDetailOutputPort } from '../../usecase/pesticides/load-pesticide-detail.output-port';
import { PesticideDetailDataDto } from '../../usecase/pesticides/load-pesticide-detail.dtos';
import { DeletePesticideOutputPort } from '../../usecase/pesticides/delete-pesticide.output-port';
import { DeletePesticideSuccessDto } from '../../usecase/pesticides/delete-pesticide.dtos';
import { UndoToastService } from '../../services/undo-toast.service';

@Injectable()
export class PesticideDetailPresenter implements LoadPesticideDetailOutputPort, DeletePesticideOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private readonly router = inject(Router);
  private view: PesticideDetailView | null = null;

  setView(view: PesticideDetailView): void {
    this.view = view;
  }

  present(dto: PesticideDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      pesticide: dto.pesticide
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      pesticide: null
    };
  }

  onSuccess(dto: DeletePesticideSuccessDto): void {
    if (dto.undo) {
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        () => this.router.navigate(['/pesticides'])
      );
    }
  }
}