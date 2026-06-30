import { inject, Injectable } from '@angular/core';
import { Router } from '@angular/router';
import { TranslateService } from '@ngx-translate/core';
import { EnsurePlanForFarmOutputPort } from '../../usecase/work-hub/ensure-plan-for-farm.output-port';
import { EnsurePlanForFarmSuccessDto } from '../../usecase/work-hub/ensure-plan-for-farm.dtos';
import { WorkHubInitOutputPort } from '../../usecase/work-hub/work-hub-init.output-port';
import { WorkHubInitPresentDto } from '../../usecase/work-hub/work-hub-init.dtos';
import { FlashMessageService } from '../../services/flash-message.service';
import { WorkHubView } from '../../components/work-hub/work-hub.view';

@Injectable()
export class WorkHubPresenter implements WorkHubInitOutputPort, EnsurePlanForFarmOutputPort {
  private readonly router = inject(Router);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly translate = inject(TranslateService);
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
      submitting: false
    };
  }

  beginEnsure(): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      submitting: true,
      error: null
    };
  }

  onError(dto: { message: string }): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      submitting: false,
      error: dto.message
    };
  }

  onSuccess(dto: EnsurePlanForFarmSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      submitting: false,
      error: null
    };
    if (dto.created) {
      this.flashMessage.show({
        type: 'success',
        text: this.translate.instant('plans.messages.plan_created')
      });
    }
    void this.router.navigate(['/plans', dto.planId, 'work']);
  }
}
