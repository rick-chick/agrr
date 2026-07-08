import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FertilizeDetailView } from '../../components/masters/fertilizes/fertilize-detail.view';
import { LoadFertilizeDetailOutputPort } from '../../usecase/fertilizes/load-fertilize-detail.output-port';
import { FertilizeDetailDataDto } from '../../usecase/fertilizes/load-fertilize-detail.dtos';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class FertilizeDetailPresenter implements LoadFertilizeDetailOutputPort {
  private view: FertilizeDetailView | null = null;

  setView(view: FertilizeDetailView): void {
    this.view = view;
  }

  present(dto: FertilizeDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      fertilize: dto.fertilize,
      pendingErrorFlash: null
    };
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
