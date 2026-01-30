import { Injectable, inject } from '@angular/core';
import { Router } from '@angular/router';
import { ErrorDto } from '../../domain/shared/error.dto';
import { InteractionRuleDetailView } from '../../components/masters/interaction-rules/interaction-rule-detail.view';
import { LoadInteractionRuleDetailOutputPort } from '../../usecase/interaction-rules/load-interaction-rule-detail.output-port';
import { InteractionRuleDetailDataDto } from '../../usecase/interaction-rules/load-interaction-rule-detail.dtos';
import { DeleteInteractionRuleOutputPort } from '../../usecase/interaction-rules/delete-interaction-rule.output-port';
import { DeleteInteractionRuleSuccessDto } from '../../usecase/interaction-rules/delete-interaction-rule.dtos';
import { UndoToastService } from '../../services/undo-toast.service';

@Injectable()
export class InteractionRuleDetailPresenter implements LoadInteractionRuleDetailOutputPort, DeleteInteractionRuleOutputPort {
  private readonly undoToast = inject(UndoToastService);
  private readonly router = inject(Router);
  private view: InteractionRuleDetailView | null = null;

  setView(view: InteractionRuleDetailView): void {
    this.view = view;
  }

  present(dto: InteractionRuleDetailDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: null,
      rule: dto.rule
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      loading: false,
      error: dto.message,
      rule: null
    };
  }

  onSuccess(dto: DeleteInteractionRuleSuccessDto): void {
    if (dto.undo) {
      this.undoToast.showWithUndo(
        dto.undo.toast_message,
        dto.undo.undo_path,
        dto.undo.undo_token,
        () => this.router.navigate(['/interaction_rules'])
      );
    }
  }
}