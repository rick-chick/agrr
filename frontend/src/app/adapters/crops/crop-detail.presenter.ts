import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropDetailView } from '../../components/masters/crops/crop-detail.view';
import { LoadCropDetailOutputPort } from '../../usecase/crops/load-crop-detail.output-port';
import { CropDetailDataDto } from '../../usecase/crops/load-crop-detail.dtos';
import { DeleteCropOutputPort } from '../../usecase/crops/delete-crop.output-port';
import { DeleteCropSuccessDto } from '../../usecase/crops/delete-crop.dtos';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';
import { CropListRefreshService } from '../../services/crop-list-refresh.service';

@Injectable()
export class CropDetailPresenter implements LoadCropDetailOutputPort, DeleteCropOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cropListRefresh = inject(CropListRefreshService);
  private view: CropDetailView | null = null;

  setView(view: CropDetailView): void {
    this.view = view;
  }

  present(dto: CropDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      crop: dto.crop
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

  onSuccess(dto: DeleteCropSuccessDto): void {
    if (dto.undo) {
      // 作物削除後は一覧へ遷移するため、Undo 時は一覧を再読込する（detail は破棄済みの可能性あり）
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        () => this.cropListRefresh.refresh()
      );
    }
  }
}
