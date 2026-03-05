import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PestDetailView } from '../../components/masters/pests/pest-detail.view';
import { LoadPestDetailOutputPort } from '../../usecase/pests/load-pest-detail.output-port';
import { PestDetailDataDto } from '../../usecase/pests/load-pest-detail.dtos';
import { DeletePestOutputPort } from '../../usecase/pests/delete-pest.output-port';
import { DeletePestSuccessDto } from '../../usecase/pests/delete-pest.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';
import { PestListRefreshService } from '../../services/pest-list-refresh.service';

@Injectable()
export class PestDetailPresenter implements LoadPestDetailOutputPort, DeletePestOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly pestListRefresh = inject(PestListRefreshService);
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
      ...this.view.control,
      loading: false,
      error: null
    };
  }

  onSuccess(dto: DeletePestSuccessDto): void {
    if (dto.undo) {
      // 害虫削除後は一覧へ遷移するため、Undo 時は一覧を再読込する（detail は破棄済みの可能性あり）
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        () => this.pestListRefresh.refresh()
      );
    }
  }
}