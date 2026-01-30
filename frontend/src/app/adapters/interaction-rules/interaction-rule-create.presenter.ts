import { Injectable, inject } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { InteractionRuleCreateView } from '../../components/masters/interaction-rules/interaction-rule-create.view';
import { CreateInteractionRuleOutputPort } from '../../usecase/interaction-rules/create-interaction-rule.output-port';
import { CreateInteractionRuleSuccessDto } from '../../usecase/interaction-rules/create-interaction-rule.dtos';
import { FlashMessageService } from '../../services/flash-message.service';

@Injectable()
export class InteractionRuleCreatePresenter implements CreateInteractionRuleOutputPort {
  private readonly flashMessage = inject(FlashMessageService);
  private view: InteractionRuleCreateView | null = null;

  setView(view: InteractionRuleCreateView): void {
    this.view = view;
  }

  present(_dto: CreateInteractionRuleSuccessDto): void {}

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.flashMessage.show({ type: 'error', text: dto.message });
    this.view.control = {
      ...this.view.control,
      saving: false,
      error: null
    };
  }
}