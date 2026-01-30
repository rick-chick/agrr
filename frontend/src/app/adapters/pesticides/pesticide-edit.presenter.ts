import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PesticideEditView } from '../../components/masters/pesticides/pesticide-edit.view';
import { LoadPesticideForEditOutputPort } from '../../usecase/pesticides/load-pesticide-for-edit.output-port';
import { LoadPesticideForEditDataDto } from '../../usecase/pesticides/load-pesticide-for-edit.dtos';
import { UpdatePesticideOutputPort } from '../../usecase/pesticides/update-pesticide.output-port';
import { UpdatePesticideSuccessDto } from '../../usecase/pesticides/update-pesticide.dtos';

@Injectable()
export class PesticideEditPresenter implements LoadPesticideForEditOutputPort, UpdatePesticideOutputPort {
  private view: PesticideEditView | null = null;

  setView(view: PesticideEditView): void {
    this.view = view;
  }

  present(dto: LoadPesticideForEditDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const pesticide = dto.pesticide;
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      formData: {
        name: pesticide.name,
        active_ingredient: pesticide.active_ingredient ?? null,
        description: pesticide.description ?? null,
        crop_id: pesticide.crop_id,
        pest_id: pesticide.pest_id,
        region: pesticide.region ?? null
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

  onSuccess(_dto: UpdatePesticideSuccessDto): void {}
}