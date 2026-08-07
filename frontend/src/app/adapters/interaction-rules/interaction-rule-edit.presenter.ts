import { Injectable } from '@angular/core';
import { ErrorDto } from '../../domain/shared/error.dto';
import { errorDtoI18nKey } from '../../core/error-dto-i18n-key';
import { InteractionRuleEditView } from '../../components/masters/interaction-rules/interaction-rule-edit.view';
import { LoadInteractionRuleForEditOutputPort } from '../../usecase/interaction-rules/load-interaction-rule-for-edit.output-port';
import { LoadInteractionRuleForEditDataDto } from '../../usecase/interaction-rules/load-interaction-rule-for-edit.dtos';
import { UpdateInteractionRuleOutputPort } from '../../usecase/interaction-rules/update-interaction-rule.output-port';
import { UpdateInteractionRuleSuccessDto } from '../../usecase/interaction-rules/update-interaction-rule.dtos';

@Injectable()
export class InteractionRuleEditPresenter implements LoadInteractionRuleForEditOutputPort, UpdateInteractionRuleOutputPort {
  private view: InteractionRuleEditView | null = null;

  setView(view: InteractionRuleEditView): void {
    this.view = view;
  }

  present(dto: LoadInteractionRuleForEditDataDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    const interactionRule = dto.interactionRule;
    this.view.control = {
      ...this.view.control,
      loading: false,
      error: null,
      formData: {
        rule_type: interactionRule.rule_type,
        source_group: interactionRule.source_group,
        target_group: interactionRule.target_group,
        impact_ratio: interactionRule.impact_ratio,
        is_directional: interactionRule.is_directional,
        description: interactionRule.description ?? null,
        region: interactionRule.region ?? null
      }
    ,
      pendingErrorFlash: null
    };
  }

  onError(dto: ErrorDto): void {
    if (!this.view) throw new Error('Presenter: view not set');
    this.view.control = {
      ...this.view.control,
      loading: false,
      saving: false,
      error: errorDtoI18nKey(dto),
      pendingErrorFlash: null
    };
  }

  onSuccess(_dto: UpdateInteractionRuleSuccessDto): void {}
}