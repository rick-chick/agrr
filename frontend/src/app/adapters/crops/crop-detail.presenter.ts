import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropDetailView } from '../../components/masters/crops/crop-detail.view';
import { LoadCropDetailOutputPort } from '../../usecase/crops/load-crop-detail.output-port';
import { CropDetailDataDto } from '../../usecase/crops/load-crop-detail.dtos';

@Injectable()
export class CropDetailPresenter implements LoadCropDetailOutputPort {
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
}
