import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropEditView } from '../../components/masters/crops/crop-edit.view';
import { LoadCropForEditOutputPort } from '../../usecase/crops/load-crop-for-edit.output-port';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { UpdateCropOutputPort } from '../../usecase/crops/update-crop.output-port';
import { UpdateCropSuccessDto } from '../../usecase/crops/update-crop.dtos';

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
      formData: {
        name: crop.name,
        variety: crop.variety ?? null,
        area_per_unit: crop.area_per_unit ?? null,
        revenue_per_area: crop.revenue_per_area ?? null,
        region: crop.region ?? null,
        groups: crop.groups ?? []
      }
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      saving: false,
      error: dto.message
    };
  }

  onSuccess(_dto: UpdateCropSuccessDto): void {}
}
