import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PestDetailView } from '../../components/masters/pests/pest-detail.view';
import { LoadPestDetailOutputPort } from '../../usecase/pests/load-pest-detail.output-port';
import { PestDetailDataDto } from '../../usecase/pests/load-pest-detail.dtos';
import { DeletePestOutputPort } from '../../usecase/pests/delete-pest.output-port';
import { DeletePestSuccessDto } from '../../usecase/pests/delete-pest.dtos';
import { FlashMessageService } from '../../services/flash-message.service';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';

@Injectable()
export class PestDetailPresenter implements LoadPestDetailOutputPort, DeletePestOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private readonly listRefreshBus = inject(ListRefreshBus);
  private view: PestDetailView | null = null;

  setView(view: PestDetailView): void {
    this.view = view;
  }

  present(dto: PestDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      pest: dto.pest,
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

  onSuccess(dto: DeletePestSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.undo) {
      // 害虫削除後は一覧へ遷移するため、Undo 時は一覧を再読込する（detail は破棄済みの可能性あり）
      this.view.control = {
        ...this.view.control,
        pendingUndoToast: pendingUndoToastFromDeletion(dto.undo, () =>
          this.listRefreshBus.refresh(LIST_REFRESH_CHANNEL.pests)
        )
      };
    }
  }
}
