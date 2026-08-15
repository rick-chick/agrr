import { Injectable } from '@angular/core';
import { WorkVarianceInitOutputPort } from '../../usecase/work-variance/work-variance-init.output-port';
import { WorkVarianceInitPresentDto } from '../../usecase/work-variance/work-variance-init.dtos';
import { WorkVarianceView } from '../../components/work-variance/work-variance.view';

@Injectable()
export class WorkVariancePresenter implements WorkVarianceInitOutputPort {
  private view: WorkVarianceView | null = null;

  setView(view: WorkVarianceView): void {
    this.view = view;
  }

  present(dto: WorkVarianceInitPresentDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      rows: dto.rows,
      filters: dto.filters,
      filterOptions: dto.filterOptions,
      farmGroups: dto.farmGroups,
      portfolioSummary: dto.portfolioSummary,
      attentionList: dto.attentionList
    };
  }

  onError(dto: { message: string }): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.message
    };
  }
}
