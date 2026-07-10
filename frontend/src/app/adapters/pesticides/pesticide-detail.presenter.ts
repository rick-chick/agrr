import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PesticideDetailView } from '../../components/masters/pesticides/pesticide-detail.view';
import { LoadPesticideDetailOutputPort } from '../../usecase/pesticides/load-pesticide-detail.output-port';
import { PesticideDetailDataDto } from '../../usecase/pesticides/load-pesticide-detail.dtos';
import { DeletePesticideOutputPort } from '../../usecase/pesticides/delete-pesticide.output-port';
import { DeletePesticideSuccessDto } from '../../usecase/pesticides/delete-pesticide.dtos';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';

@Injectable()
export class PesticideDetailPresenter implements LoadPesticideDetailOutputPort, DeletePesticideOutputPort {
  private readonly listRefreshBus = inject(ListRefreshBus);
  private view: PesticideDetailView | null = null;

  setView(view: PesticideDetailView): void {
    this.view = view;
  }

  present(dto: PesticideDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      pesticide: dto.pesticide,
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.message,
      pendingErrorFlash: null
    };
  }

  onSuccess(dto: DeletePesticideSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.undo) {
      // 農薬削除後は一覧へ遷移するため、Undo 時は一覧を再読込する（detail は破棄済みの可能性あり）
      this.view.control = {
        ...this.view.control,
        pendingUndoToast: pendingUndoToastFromDeletion(dto.undo, () =>
          this.listRefreshBus.refresh(LIST_REFRESH_CHANNEL.pesticides)
        )
      };
    }
  }
}
