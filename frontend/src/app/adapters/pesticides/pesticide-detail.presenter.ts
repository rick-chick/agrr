import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PesticideDetailView } from '../../components/masters/pesticides/pesticide-detail.view';
import { LoadPesticideDetailOutputPort } from '../../usecase/pesticides/load-pesticide-detail.output-port';
import { PesticideDetailDataDto } from '../../usecase/pesticides/load-pesticide-detail.dtos';
import { DeletePesticideOutputPort } from '../../usecase/pesticides/delete-pesticide.output-port';
import { DeletePesticideSuccessDto } from '../../usecase/pesticides/delete-pesticide.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';
import { PesticideListRefreshService } from '../../services/pesticide-list-refresh.service';

@Injectable()
export class PesticideDetailPresenter implements LoadPesticideDetailOutputPort, DeletePesticideOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly pesticideListRefresh = inject(PesticideListRefreshService);
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
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null
    };
  }

  onSuccess(dto: DeletePesticideSuccessDto): void {
    if (dto.undo) {
      // 農薬削除後は一覧へ遷移するため、Undo 時は一覧を再読込する（detail は破棄済みの可能性あり）
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        () => this.pesticideListRefresh.refresh()
      );
    }
  }
}