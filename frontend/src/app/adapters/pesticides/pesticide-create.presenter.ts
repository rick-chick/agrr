import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PesticideCreateView } from '../../components/masters/pesticides/pesticide-create.view';
import { CreatePesticideOutputPort } from '../../usecase/pesticides/create-pesticide.output-port';
import { CreatePesticideSuccessDto } from '../../usecase/pesticides/create-pesticide.dtos';

@Injectable()
export class PesticideCreatePresenter implements CreatePesticideOutputPort {
  private view: PesticideCreateView | null = null;

  setView(view: PesticideCreateView): void {
    this.view = view;
  }

  onSuccess(_dto: CreatePesticideSuccessDto): void {}

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      saving: false,
      error: dto.message
    };
  }
}