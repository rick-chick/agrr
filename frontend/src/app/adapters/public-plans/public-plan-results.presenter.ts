import { Injectable } from '@angular/core';
import { PublicPlanResultsView } from '../../components/public-plans/public-plan-results.view';
import { LoadPublicPlanResultsOutputPort } from '../../usecase/public-plans/load-public-plan-results.output-port';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { ErrorDto } from '../../domain/shared/error.dto';

@Injectable()
export class PublicPlanResultsPresenter implements LoadPublicPlanResultsOutputPort {
  private view: PublicPlanResultsView | null = null;

  setView(view: PublicPlanResultsView): void {
    this.view = view;
  }

  present(dto: CultivationPlanData): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      data: dto
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.message,
      data: null
    };
  }
}
