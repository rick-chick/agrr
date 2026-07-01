import { Injectable } from '@angular/core';
import { PublicPlanResultsView } from '../../components/public-plans/public-plan-results.view';
import { LoadPublicPlanResultsOutputPort } from '../../usecase/public-plans/load-public-plan-results.output-port';
import { SavePublicPlanOutputPort } from '../../usecase/public-plans/save-public-plan.output-port';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { ErrorDto } from '../../domain/shared/error.dto';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';
import { pendingSuccessFlashFromText } from '../../core/view-effects/pending-success-flash-presenter.helpers';
import { pendingNavigationTo } from '../../core/view-effects/pending-navigation-presenter.helpers';

@Injectable()
export class PublicPlanResultsPresenter implements LoadPublicPlanResultsOutputPort, SavePublicPlanOutputPort {
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
      if (!this.view) throw new Error('Presenter: view not set');
      this.view.control = {
        ...this.view.control,
        pendingErrorFlash: null,
        pendingSuccessFlash: pendingSuccessFlashFromText(dto.message),
        pendingNavigation: dto.cultivation_plan_id
          ? pendingNavigationTo(['/plans', dto.cultivation_plan_id])
          : pendingNavigationTo(['/plans'])
      };
      return;
    }
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      data: dto as CultivationPlanData,
      pendingErrorFlash: null,
      pendingSuccessFlash: null
    };
  }

  onError(dto: ErrorDto | { message: string }): void {
    if (!this.view) {
      return;
    }
    const pendingErrorFlash = pendingErrorFlashFromError(dto);
    // 保存失敗時はガントを維持（読み込み失敗のみ全画面エラー）
    if (this.view.control.data) {
      this.view.control = {
        ...this.view.control,
        loading: false,
        pendingSuccessFlash: null,
        pendingErrorFlash
      };
      return;
    }
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: dto.message,
      data: null,
      pendingSuccessFlash: null,
      pendingErrorFlash
    };
  }
}
