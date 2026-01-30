import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PestCreateView } from '../../components/masters/pests/pest-create.view';
import { CreatePestOutputPort } from '../../usecase/pests/create-pest.output-port';
import { CreatePestSuccessDto } from '../../usecase/pests/create-pest.dtos';

@Injectable()
export class PestCreatePresenter implements CreatePestOutputPort {
  private view: PestCreateView | null = null;

  setView(view: PestCreateView): void {
    this.view = view;
  }

  onSuccess(_dto: CreatePestSuccessDto): void {}

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      saving: false,
      error: dto.message
    };
  }
}