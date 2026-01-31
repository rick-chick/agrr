import { Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';
import { PublicPlanResultsView } from '../../components/public-plans/public-plan-results.view';
import { LoadPublicPlanResultsOutputPort } from '../../usecase/public-plans/load-public-plan-results.output-port';
import { SavePublicPlanOutputPort, SAVE_PUBLIC_PLAN_OUTPUT_PORT } from '../../usecase/public-plans/save-public-plan.output-port';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { ErrorDto } from '../../domain/shared/error.dto';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class PublicPlanResultsPresenter implements LoadPublicPlanResultsOutputPort, SavePublicPlanOutputPort {
  private readonly router = inject(Router);
  private readonly flashMessage = inject(FlashMessageService);
  private view: PublicPlanResultsView | null = null;

  setView(view: PublicPlanResultsView): void {
    this.view = view;
  }

  present(dto: CultivationPlanData | { message: string }): void {
    if ('message' in dto && !('plan' in dto)) {
      this.flashMessage.show({ type: 'success', text: dto.message });
      this.router.navigate(['/plans']);
      return;
    }
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      data: dto as CultivationPlanData
    };
  }

  onError(dto: ErrorDto | { message: string }): void {
    const message = dto.message;
    if (this.view) {
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: message,
        data: null
      };
    }
    this.flashMessage.show({ type: 'error', text: message });
  }
}
