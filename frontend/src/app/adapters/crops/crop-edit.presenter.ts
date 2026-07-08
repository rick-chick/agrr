import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropEditView } from '../../components/masters/crops/crop-edit.view';
import { LoadCropForEditOutputPort } from '../../usecase/crops/load-crop-for-edit.output-port';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { UpdateCropOutputPort } from '../../usecase/crops/update-crop.output-port';
import { UpdateCropSuccessDto } from '../../usecase/crops/update-crop.dtos';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';
import { pendingSuccessFlashFromText } from '../../core/view-effects/pending-success-flash-presenter.helpers';

@Injectable()
export class CropEditPresenter implements LoadCropForEditOutputPort, UpdateCropOutputPort {
  private view: CropEditView | null = null;

  setView(view: CropEditView): void {
    this.view = view;
  }

  present(dto: LoadCropForEditDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const crop = dto.crop;
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      pendingSuccessFlash: null,
      pendingErrorFlash: null,
      formData: {
        name: crop.name,
        variety: crop.variety ?? null,
        area_per_unit: crop.area_per_unit ?? null,
        revenue_per_area: crop.revenue_per_area ?? null,
        region: crop.region ?? null,
        groups: crop.groups ?? [],
        groupsDisplay: (crop.groups ?? []).join(', '),
        is_reference: crop.is_reference ?? false
      }
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      saving: false,
      error: null,
      pendingSuccessFlash: null,
      pendingErrorFlash: pendingErrorFlashFromError(dto)
    };
  }

  onSuccess(_dto: UpdateCropSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      saving: false,
      pendingErrorFlash: null,
      pendingSuccessFlash: pendingSuccessFlashFromText('crops.flash.updated')
    };
  }
}
