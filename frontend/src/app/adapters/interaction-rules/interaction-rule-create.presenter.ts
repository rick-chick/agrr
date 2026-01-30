import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { InteractionRuleCreateView } from '../../components/masters/interaction-rules/interaction-rule-create.view';
import { CreateInteractionRuleOutputPort } from '../../usecase/interaction-rules/create-interaction-rule.output-port';
import { CreateInteractionRuleSuccessDto } from '../../usecase/interaction-rules/create-interaction-rule.dtos';

@Injectable()
export class InteractionRuleCreatePresenter implements CreateInteractionRuleOutputPort {
  private view: InteractionRuleCreateView | null = null;

  setView(view: InteractionRuleCreateView): void {
    this.view = view;
  }

  present(_dto: CreateInteractionRuleSuccessDto): void {}

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      saving: false,
      error: dto.message
    };
  }
}