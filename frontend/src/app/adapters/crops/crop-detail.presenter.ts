import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropDetailView } from '../../components/masters/crops/crop-detail.view';
import { LoadCropDetailOutputPort } from '../../usecase/crops/load-crop-detail.output-port';
import { CropDetailDataDto } from '../../usecase/crops/load-crop-detail.dtos';
import { DeleteCropOutputPort } from '../../usecase/crops/delete-crop.output-port';
import { DeleteCropSuccessDto } from '../../usecase/crops/delete-crop.dtos';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';
import {
  LoadCropTaskScheduleBlueprintsDataDto,
  LoadCropTaskScheduleBlueprintsOutputPort
} from '../../usecase/crops/crop-task-schedule-blueprint.ports';
import { withCropDetailSummaryState } from './crop-detail-display-state';

@Injectable()
export class CropDetailPresenter
  implements LoadCropDetailOutputPort, DeleteCropOutputPort, LoadCropTaskScheduleBlueprintsOutputPort
{
  private readonly listRefreshBus = inject(ListRefreshBus);
  private view: CropDetailView | null = null;

  setView(view: CropDetailView): void {
    this.view = view;
  }

  present(dto: CropDetailDataDto): void;
  present(dto: LoadCropTaskScheduleBlueprintsDataDto): void;
  present(dto: CropDetailDataDto | LoadCropTaskScheduleBlueprintsDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');

    if ('crop' in dto) {
      this.view.control = withCropDetailSummaryState({
        ...this.view.control,
        loading: false,
        error: null,
        crop: dto.crop,
        pendingUndoToast: null,
        pendingErrorFlash: null
      });
      return;
    }

    if ('blueprints' in dto) {
      this.view.control = withCropDetailSummaryState(
        {
          ...this.view.control,
          blueprintsLoading: false,
          pendingErrorFlash: null
        },
        dto.blueprints
      );
    }
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = withCropDetailSummaryState({
      ...this.view.control,
      loading: false,
      blueprintsLoading: false,
      error: null,
      pendingErrorFlash: pendingErrorFlashFromError(dto)
    });
  }

  onSuccess(dto: DeleteCropSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.undo) {
      this.view.control = withCropDetailSummaryState({
        ...this.view.control,
        pendingUndoToast: pendingUndoToastFromDeletion(dto.undo, () =>
          this.listRefreshBus.refresh(LIST_REFRESH_CHANNEL.crops)
        )
      });
    }
  }
}
