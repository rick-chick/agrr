import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { PestListView } from '../../components/masters/pests/pest-list.view';
import { LoadPestListOutputPort } from '../../usecase/pests/load-pest-list.output-port';
import { PestListDataDto } from '../../usecase/pests/load-pest-list.dtos';

@Injectable()
export class PestListPresenter implements LoadPestListOutputPort {
  private view: PestListView | null = null;

  setView(view: PestListView): void {
    this.view = view;
  }

  present(dto: PestListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      pests: dto.pests
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      pests: []
    };
  }
}
