import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { InteractionRuleListView } from '../../components/masters/interaction-rules/interaction-rule-list.view';
import { LoadInteractionRuleListOutputPort } from '../../usecase/interaction-rules/load-interaction-rule-list.output-port';
import { InteractionRuleListDataDto } from '../../usecase/interaction-rules/load-interaction-rule-list.dtos';
import { DeleteInteractionRuleOutputPort } from '../../usecase/interaction-rules/delete-interaction-rule.output-port';
import { DeleteInteractionRuleSuccessDto } from '../../usecase/interaction-rules/delete-interaction-rule.dtos';
import { PendingUndoToastRequest } from '../../core/view-effects/pending-undo-toast-view.effects';
import { pendingUndoToastFromDeletion } from '../../core/view-effects/pending-undo-toast-presenter.helpers';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';

@Injectable()
export class InteractionRuleListPresenter implements LoadInteractionRuleListOutputPort, DeleteInteractionRuleOutputPort {
  private view: InteractionRuleListView | null = null;

  setView(view: InteractionRuleListView): void {
    this.view = view;
  }

  present(dto: InteractionRuleListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      rules: dto.rules,
      pendingUndoToast: null,
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

  onSuccess(dto: DeleteInteractionRuleSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    const nextControl = {
      ...prev,
      rules: prev.rules.filter((r) => r.id !== dto.deletedInteractionRuleId),
      pendingUndoToast: null as PendingUndoToastRequest | null
    };
    if (dto.undo && dto.refresh) {
      nextControl.pendingUndoToast = pendingUndoToastFromDeletion(dto.undo, dto.refresh);
    }
    this.view.control = nextControl;
  }
}
