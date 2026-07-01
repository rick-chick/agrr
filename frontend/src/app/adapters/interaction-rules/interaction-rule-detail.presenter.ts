import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { InteractionRuleDetailView } from '../../components/masters/interaction-rules/interaction-rule-detail.view';
import { LoadInteractionRuleDetailOutputPort } from '../../usecase/interaction-rules/load-interaction-rule-detail.output-port';
import { InteractionRuleDetailDataDto } from '../../usecase/interaction-rules/load-interaction-rule-detail.dtos';
import { DeleteInteractionRuleOutputPort } from '../../usecase/interaction-rules/delete-interaction-rule.output-port';
import { DeleteInteractionRuleSuccessDto } from '../../usecase/interaction-rules/delete-interaction-rule.dtos';
import { FlashMessageService } from '../../services/flash-message.service';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import { LIST_REFRESH_CHANNEL } from '../../core/list-refresh/list-refresh-keys';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';

@Injectable()
export class InteractionRuleDetailPresenter implements LoadInteractionRuleDetailOutputPort, DeleteInteractionRuleOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
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
      rule: dto.rule,
      pendingUndoToast: null
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null
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
