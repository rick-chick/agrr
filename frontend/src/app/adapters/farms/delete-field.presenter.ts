import { Injectable, inject } from '@angular/core';
import { DeleteFieldOutputPort } from '../../usecase/farms/delete-field.output-port';
import { FarmDetailView } from '../../components/masters/farms/farm-detail.view';
import { DeleteFieldOutputDto } from '../../usecase/farms/delete-field.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';

@Injectable()
export class DeleteFieldPresenter implements DeleteFieldOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: FarmDetailView | null = null;

  setView(view: FarmDetailView): void {
    this.view = view;
  }

  present(dto: DeleteFieldOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');

    if (dto.undo) {
      this.view.control = {
        ...this.view.control,
        pendingUndoToast: pendingUndoToastFromDeletion(dto.undo, () => {
          // 復元成功時は一覧を再取得
          this.view?.load?.(dto.farmId);
        })
      };
    } else {
      // undo がなくても削除成功時は一覧を再取得
      this.view.load?.(dto.farmId);
    }
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
}
