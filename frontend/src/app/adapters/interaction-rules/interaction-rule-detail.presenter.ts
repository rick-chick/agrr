import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { errorDtoI18nKey } from '../../core/error-dto-i18n-key';
import { masterLoadErrorFromDto } from '../masters/master-load-error-presenter.helpers';
import { InteractionRuleDetailView } from '../../components/masters/interaction-rules/interaction-rule-detail.view';
import { LoadInteractionRuleDetailOutputPort } from '../../usecase/interaction-rules/load-interaction-rule-detail.output-port';
import { InteractionRuleDetailDataDto } from '../../usecase/interaction-rules/load-interaction-rule-detail.dtos';
import { DeleteInteractionRuleOutputPort } from '../../usecase/interaction-rules/delete-interaction-rule.output-port';
import { DeleteInteractionRuleSuccessDto } from '../../usecase/interaction-rules/delete-interaction-rule.dtos';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class InteractionRuleDetailPresenter implements LoadInteractionRuleDetailOutputPort, DeleteInteractionRuleOutputPort {
  private readonly listRefreshBus = inject(ListRefreshBus);
  private view: InteractionRuleDetailView | null = null;

  setView(view: InteractionRuleDetailView): void {
    this.view = view;
  }

  present(dto: InteractionRuleDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      errorIsWarmup: false,
      rule: dto.rule,
      pendingUndoToast: null,
      pendingErrorFlash: null
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (this.view.control.loading) {
      const { errorKey, isWarmupError } = masterLoadErrorFromDto(dto);
      this.view.control = {
        ...this.view.control,
        loading: false,
        error: errorKey,
        errorIsWarmup: isWarmupError,
        pendingErrorFlash: null
      };
      return;
    }
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      errorIsWarmup: false,
      pendingErrorFlash: pendingErrorFlashFromError({ message: errorDtoI18nKey(dto) })
    };
  }

  onSuccess(dto: DeleteInteractionRuleSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    if (dto.undo) {
      // 相互作用ルール削除後は一覧へ遷移するため、Undo 時は一覧を再読込する（detail は破棄済みの可能性あり）
      this.view.control = {
        ...this.view.control,
        pendingUndoToast: pendingUndoToastFromDeletion(dto.undo, () =>
          this.listRefreshBus.refresh(LIST_REFRESH_CHANNEL.interactionRules)
        )
      };
    }
  }
}
