import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { InteractionRuleListView } from '../../components/masters/interaction-rules/interaction-rule-list.view';
import { LoadInteractionRuleListOutputPort } from '../../usecase/interaction-rules/load-interaction-rule-list.output-port';
import { InteractionRuleListDataDto } from '../../usecase/interaction-rules/load-interaction-rule-list.dtos';

@Injectable()
export class InteractionRuleListPresenter implements LoadInteractionRuleListOutputPort {
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
}
