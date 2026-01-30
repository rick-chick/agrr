import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropListView } from '../../components/masters/crops/crop-list.view';
import { LoadCropListOutputPort } from '../../usecase/crops/load-crop-list.output-port';
import { CropListDataDto } from '../../usecase/crops/load-crop-list.dtos';

@Injectable()
export class CropListPresenter implements LoadCropListOutputPort {
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
      loading: false,
      error: dto.message,
      crops: []
    };
  }
}
