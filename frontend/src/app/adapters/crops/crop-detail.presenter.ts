import { Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropDetailView } from '../../components/masters/crops/crop-detail.view';
import { LoadCropDetailOutputPort } from '../../usecase/crops/load-crop-detail.output-port';
import { CropDetailDataDto } from '../../usecase/crops/load-crop-detail.dtos';
import { DeleteCropOutputPort } from '../../usecase/crops/delete-crop.output-port';
import { DeleteCropSuccessDto } from '../../usecase/crops/delete-crop.dtos';
import { UndoToastService } from '../../services/undo-toast.service';

@Injectable()
export class CropDetailPresenter implements LoadCropDetailOutputPort, DeleteCropOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private readonly router = inject(Router);
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
    this.view.control = {
      loading: false,
      error: dto.message,
      crop: null
    };
  }

  onSuccess(dto: DeleteCropSuccessDto): void {
    if (dto.undo) {
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        () => this.router.navigate(['/crops'])
      );
    }
  }
}
