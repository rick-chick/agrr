import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropListView } from '../../components/masters/crops/crop-list.view';
import { LoadCropListOutputPort } from '../../usecase/crops/load-crop-list.output-port';
import { CropListDataDto } from '../../usecase/crops/load-crop-list.dtos';
import { DeleteCropOutputPort } from '../../usecase/crops/delete-crop.output-port';
import { DeleteCropSuccessDto } from '../../usecase/crops/delete-crop.dtos';
import { UndoToastService } from '../../services/undo-toast.service';

@Injectable()
export class CropListPresenter implements LoadCropListOutputPort, DeleteCropOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private view: CropListView | null = null;

  setView(view: CropListView): void {
    this.view = view;
  }

  present(dto: CropListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      crops: dto.crops
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.message
    };
  }

  onSuccess(dto: DeleteCropSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    this.view.control = {
      ...prev,
      crops: prev.crops.filter((c) => c.id !== dto.deletedCropId)
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
