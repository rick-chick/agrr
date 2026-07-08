import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { AgriculturalTaskDetailView } from '../../components/masters/agricultural-tasks/agricultural-task-detail.view';
import { LoadAgriculturalTaskDetailOutputPort } from '../../usecase/agricultural-tasks/load-agricultural-task-detail.output-port';
import { LoadAgriculturalTaskDetailDataDto } from '../../usecase/agricultural-tasks/load-agricultural-task-detail.dtos';
import { DeleteAgriculturalTaskOutputPort } from '../../usecase/agricultural-tasks/delete-agricultural-task.output-port';
import { DeleteAgriculturalTaskSuccessDto } from '../../usecase/agricultural-tasks/delete-agricultural-task.dtos';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class AgriculturalTaskDetailPresenter implements LoadAgriculturalTaskDetailOutputPort, DeleteAgriculturalTaskOutputPort {
  private readonly listRefreshBus = inject(ListRefreshBus);
  private view: AgriculturalTaskDetailView | null = null;

  setView(view: AgriculturalTaskDetailView): void {
    this.view = view;
  }

  present(dto: LoadAgriculturalTaskDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      agriculturalTask: dto.agriculturalTask,
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

  onSuccess(dto: DeleteAgriculturalTaskSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.undo) {
      // 農業作業削除後は一覧へ遷移するため、Undo 時は一覧を再読込する（detail は破棄済みの可能性あり）
      this.view.control = {
        ...this.view.control,
        pendingUndoToast: pendingUndoToastFromDeletion(dto.undo, () =>
          this.listRefreshBus.refresh(LIST_REFRESH_CHANNEL.agriculturalTasks)
        )
      };
    }
  }
}
