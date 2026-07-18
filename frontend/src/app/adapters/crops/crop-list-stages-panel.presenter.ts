import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropListStagesPanelView } from '../../components/masters/crops/crop-list-stages-panel.view';
import { LoadCropForEditOutputPort } from '../../usecase/crops/load-crop-for-edit.output-port';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';

@Injectable()
export class CropListStagesPanelPresenter implements LoadCropForEditOutputPort {
  private view: CropListStagesPanelView | null = null;

  setView(view: CropListStagesPanelView): void {
    this.view = view;
  }

  present(dto: LoadCropForEditDataDto): void {
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
}
