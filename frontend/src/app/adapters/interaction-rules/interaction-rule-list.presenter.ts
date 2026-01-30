import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { InteractionRuleListView } from '../../components/masters/interaction-rules/interaction-rule-list.view';
import { LoadInteractionRuleListOutputPort } from '../../usecase/interaction-rules/load-interaction-rule-list.output-port';
import { InteractionRuleListDataDto } from '../../usecase/interaction-rules/load-interaction-rule-list.dtos';
import { DeleteInteractionRuleOutputPort } from '../../usecase/interaction-rules/delete-interaction-rule.output-port';
import { DeleteInteractionRuleSuccessDto } from '../../usecase/interaction-rules/delete-interaction-rule.dtos';
import { UndoToastService } from '../../services/undo-toast.service';

@Injectable()
export class InteractionRuleListPresenter implements LoadInteractionRuleListOutputPort, DeleteInteractionRuleOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private view: InteractionRuleListView | null = null;

  setView(view: InteractionRuleListView): void {
    this.view = view;
  }

  present(dto: InteractionRuleListDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      rules: dto.rules
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      rules: []
    };
  }

  onSuccess(dto: DeleteInteractionRuleSuccessDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const prev = this.view.control;
    this.view.control = {
      ...prev,
      rules: prev.rules.filter((r) => r.id !== dto.deletedInteractionRuleId)
    };
    if (dto.undo && dto.refresh) {
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        dto.refresh
      );
    }
  }
}
