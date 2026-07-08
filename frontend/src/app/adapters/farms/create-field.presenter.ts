import { Injectable } from '@angular/core';
import { CreateFieldOutputPort } from '../../usecase/farms/create-field.output-port';
import { FarmDetailView } from '../../components/masters/farms/farm-detail.view';
import { CreateFieldOutputDto } from '../../usecase/farms/create-field.dtos';
import { ErrorDto } from '../../domain/shared/error.dto';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class CreateFieldPresenter implements CreateFieldOutputPort {
  private view: FarmDetailView | null = null;

  setView(view: FarmDetailView): void {
    this.view = view;
  }

  present(dto: CreateFieldOutputDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.load?.(dto.farmId);
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      pendingErrorFlash: pendingErrorFlashFromError(dto)
    };
  }
}