import { Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';
import { PublicPlanResultsView } from '../../components/public-plans/public-plan-results.view';
import { LoadPublicPlanResultsOutputPort } from '../../usecase/public-plans/load-public-plan-results.output-port';
import { SavePublicPlanOutputPort } from '../../usecase/public-plans/save-public-plan.output-port';
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

  present(
    dto:
      | CultivationPlanData
      | { message: string; cultivation_plan_id?: number; plan_reused?: boolean }
  ): void {
    if ('message' in dto && !('plan' in dto)) {
      this.flashMessage.show({ type: 'success', text: dto.message });
      if (dto.cultivation_plan_id) {
        void this.router.navigate(['/plans', dto.cultivation_plan_id]);
      } else {
        void this.router.navigate(['/plans']);
      }
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
    this.flashMessage.show({ type: 'error', text: message });
    if (!this.view) {
      return;
    }
    // 保存失敗時はガントを維持（読み込み失敗のみ全画面エラー）
    if (this.view.control.data) {
      this.view.control = {
        ...this.view.control,
        loading: false
      };
      return;
    }
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: message,
      data: null
    };
  }
}
