import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PesticideListView } from '../../components/masters/pesticides/pesticide-list.view';
import { LoadPesticideListOutputPort } from '../../usecase/pesticides/load-pesticide-list.output-port';
import { PesticideListDataDto } from '../../usecase/pesticides/load-pesticide-list.dtos';

@Injectable()
export class PesticideListPresenter implements LoadPesticideListOutputPort {
  private view: PesticideListView | null = null;

  setView(view: PesticideListView): void {
    this.view = view;
  }

  present(dto: PesticideListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      pesticides: dto.pesticides
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      pesticides: []
    };
  }
}
