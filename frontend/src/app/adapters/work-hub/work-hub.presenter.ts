import { Injectable } from '@angular/core';
import { EnsurePlanForFarmOutputPort } from '../../usecase/work-hub/ensure-plan-for-farm.output-port';
import { EnsurePlanForFarmSuccessDto } from '../../usecase/work-hub/ensure-plan-for-farm.dtos';
import { WorkHubInitOutputPort } from '../../usecase/work-hub/work-hub-init.output-port';
import { WorkHubInitPresentDto } from '../../usecase/work-hub/work-hub-init.dtos';
import { WorkHubView } from '../../components/work-hub/work-hub.view';
import { pendingSuccessFlashFromText } from '../../core/view-effects/pending-success-flash-presenter.helpers';
import { pendingNavigationTo } from '../../core/view-effects/pending-navigation-presenter.helpers';

@Injectable()
export class WorkHubPresenter
  implements WorkHubInitOutputPort, EnsurePlanForFarmOutputPort
{
  private view: WorkHubView | null = null;

  setView(view: WorkHubView): void {
    this.view = view;
  }

  present(dto: WorkHubInitPresentDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      farms: dto.farms,
      submitting: false,
      pendingSuccessFlash: null
    };
  }

  beginEnsure(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      submitting: true,
      error: null,
      pendingSuccessFlash: null
    };
  }

  onError(dto: { message: string }): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      submitting: false,
      error: dto.message,
      pendingSuccessFlash: null
    };
  }

  onSuccess(dto: EnsurePlanForFarmSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      submitting: false,
      error: null,
      pendingSuccessFlash: dto.created
        ? pendingSuccessFlashFromText('plans.messages.plan_created')
        : null,
      pendingNavigation: pendingNavigationTo(['/plans', dto.planId, 'work'])
    };
  }
}
