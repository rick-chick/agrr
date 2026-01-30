import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { CropCreateView } from '../../components/masters/crops/crop-create.view';
import { CreateCropOutputPort } from '../../usecase/crops/create-crop.output-port';
import { CreateCropSuccessDto } from '../../usecase/crops/create-crop.dtos';

@Injectable()
export class CropCreatePresenter implements CreateCropOutputPort {
  private view: CropCreateView | null = null;

  setView(view: CropCreateView): void {
    this.view = view;
  }

  onSuccess(_dto: CreateCropSuccessDto): void {}

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      saving: false,
      error: dto.message
    };
  }
}
