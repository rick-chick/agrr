import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FarmCreateView } from '../../components/masters/farms/farm-create.view';
import { CreateFarmOutputPort } from '../../usecase/farms/create-farm.output-port';
import { CreateFarmSuccessDto } from '../../usecase/farms/create-farm.dtos';

@Injectable()
export class FarmCreatePresenter implements CreateFarmOutputPort {
  private view: FarmCreateView | null = null;

  setView(view: FarmCreateView): void {
    this.view = view;
  }

  onSuccess(_dto: CreateFarmSuccessDto): void {
    // Navigation is handled by Component's onSuccess callback
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      saving: false,
      error: dto.message
    };
  }
}
