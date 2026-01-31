import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { InteractionRuleCreateView, InteractionRuleCreateViewState, InteractionRuleCreateFormData } from './interaction-rule-create.view';
import { CreateInteractionRuleUseCase } from '../../../usecase/interaction-rules/create-interaction-rule.usecase';
import { InteractionRuleCreatePresenter } from '../../../adapters/interaction-rules/interaction-rule-create.presenter';
import { CREATE_INTERACTION_RULE_OUTPUT_PORT } from '../../../usecase/interaction-rules/create-interaction-rule.output-port';
import { INTERACTION_RULE_GATEWAY } from '../../../usecase/interaction-rules/interaction-rule-gateway';
import { InteractionRuleApiGateway } from '../../../adapters/interaction-rules/interaction-rule-api.gateway';

const initialFormData: InteractionRuleCreateFormData = {
  rule_type: 'continuous_cultivation',
  source_group: '',
  target_group: '',
  impact_ratio: 0,
  is_directional: false,
  description: null,
  region: null
};

const initialControl: InteractionRuleCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-interaction-rule-create',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule, RegionSelectComponent],
  providers: [
    InteractionRuleCreatePresenter,
    CreateInteractionRuleUseCase,
    { provide: CREATE_INTERACTION_RULE_OUTPUT_PORT, useExisting: InteractionRuleCreatePresenter },
    { provide: INTERACTION_RULE_GATEWAY, useClass: InteractionRuleApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'interaction_rules.new.title' | translate }}</h2>
        <form (ngSubmit)="createInteractionRule()" #interactionRuleForm="ngForm" class="form-card__form">
          <label class="form-card__field" for="rule_type">
            <span class="form-card__field-label">{{ 'interaction_rules.form.rule_type_label' | translate }}</span>
            <input id="rule_type" name="rule_type" [(ngModel)]="control.formData.rule_type" required />
          </label>
          <label class="form-card__field" for="source_group">
            <span class="form-card__field-label">{{ 'interaction_rules.form.source_group_label' | translate }}</span>
            <input id="source_group" name="source_group" [(ngModel)]="control.formData.source_group" required />
          </label>
          <label class="form-card__field" for="target_group">
            <span class="form-card__field-label">{{ 'interaction_rules.form.target_group_label' | translate }}</span>
            <input id="target_group" name="target_group" [(ngModel)]="control.formData.target_group" required />
          </label>
          <label class="form-card__field" for="impact_ratio">
            <span class="form-card__field-label">{{ 'interaction_rules.form.impact_ratio_label' | translate }}</span>
            <input id="impact_ratio" name="impact_ratio" type="number" step="0.01" [(ngModel)]="control.formData.impact_ratio" required />
          </label>
          <label class="form-card__field" for="is_directional">
            <span class="form-card__field-label">{{ 'interaction_rules.form.is_directional_label' | translate }}</span>
            <input id="is_directional" name="is_directional" type="checkbox" [(ngModel)]="control.formData.is_directional" />
          </label>
          <label class="form-card__field" for="description">
            <span class="form-card__field-label">{{ 'interaction_rules.form.description_label' | translate }}</span>
            <textarea id="description" name="description" [(ngModel)]="control.formData.description"></textarea>
          </label>
          <app-region-select
            [region]="control.formData.region"
            (regionChange)="control.formData.region = $event">
          </app-region-select>
          <div class="form-card__actions">
            <button type="submit" class="btn-primary" [disabled]="interactionRuleForm.invalid || control.saving">
              {{ 'interaction_rules.form.submit_create' | translate }}
            </button>
            <a [routerLink]="['/interaction_rules']" class="btn-secondary">{{ 'common.back' | translate }}</a>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrl: './interaction-rule-create.component.css'
})
export class InteractionRuleCreateComponent implements InteractionRuleCreateView, OnInit {
  private readonly router = inject(Router);
  private readonly useCase = inject(CreateInteractionRuleUseCase);
  private readonly presenter = inject(InteractionRuleCreatePresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: InteractionRuleCreateViewState = initialControl;
  get control(): InteractionRuleCreateViewState {
    return this._control;
  }
  set control(value: InteractionRuleCreateViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
  }

  createInteractionRule(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    this.useCase.execute({
      ...this.control.formData,
      onSuccess: () => this.router.navigate(['/interaction_rules'])
    });
  }
}