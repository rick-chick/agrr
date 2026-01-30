import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { InteractionRuleEditView, InteractionRuleEditViewState, InteractionRuleEditFormData } from './interaction-rule-edit.view';
import { LoadInteractionRuleForEditUseCase } from '../../../usecase/interaction-rules/load-interaction-rule-for-edit.usecase';
import { UpdateInteractionRuleUseCase } from '../../../usecase/interaction-rules/update-interaction-rule.usecase';
import { InteractionRuleEditPresenter } from '../../../adapters/interaction-rules/interaction-rule-edit.presenter';
import { LOAD_INTERACTION_RULE_FOR_EDIT_OUTPUT_PORT } from '../../../usecase/interaction-rules/load-interaction-rule-for-edit.output-port';
import { UPDATE_INTERACTION_RULE_OUTPUT_PORT } from '../../../usecase/interaction-rules/update-interaction-rule.output-port';
import { INTERACTION_RULE_GATEWAY } from '../../../usecase/interaction-rules/interaction-rule-gateway';
import { InteractionRuleApiGateway } from '../../../adapters/interaction-rules/interaction-rule-api.gateway';

const initialFormData: InteractionRuleEditFormData = {
  rule_type: '',
  source_group: '',
  target_group: '',
  impact_ratio: 0,
  is_directional: false,
  description: null,
  region: null
};

const initialControl: InteractionRuleEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
};

@Component({
  selector: 'app-interaction-rule-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, RouterLink, TranslateModule],
  providers: [
    InteractionRuleEditPresenter,
    LoadInteractionRuleForEditUseCase,
    UpdateInteractionRuleUseCase,
    { provide: LOAD_INTERACTION_RULE_FOR_EDIT_OUTPUT_PORT, useExisting: InteractionRuleEditPresenter },
    { provide: UPDATE_INTERACTION_RULE_OUTPUT_PORT, useExisting: InteractionRuleEditPresenter },
    { provide: INTERACTION_RULE_GATEWAY, useClass: InteractionRuleApiGateway }
  ],
  template: `
    <main class="page-main">
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'interaction_rules.edit.title' | translate }}</h2>
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <form (ngSubmit)="updateInteractionRule()" #interactionRuleForm="ngForm" class="form-card__form">
            <label class="form-card__field">
              {{ 'interaction_rules.form.rule_type_label' | translate }}
              <input name="rule_type" [(ngModel)]="control.formData.rule_type" required />
            </label>
            <label class="form-card__field">
              {{ 'interaction_rules.form.source_group_label' | translate }}
              <input name="source_group" [(ngModel)]="control.formData.source_group" required />
            </label>
            <label class="form-card__field">
              {{ 'interaction_rules.form.target_group_label' | translate }}
              <input name="target_group" [(ngModel)]="control.formData.target_group" required />
            </label>
            <label class="form-card__field">
              {{ 'interaction_rules.form.impact_ratio_label' | translate }}
              <input name="impact_ratio" type="number" step="0.01" [(ngModel)]="control.formData.impact_ratio" required />
            </label>
            <label class="form-card__field">
              {{ 'interaction_rules.form.is_directional_label' | translate }}
              <input name="is_directional" type="checkbox" [(ngModel)]="control.formData.is_directional" />
            </label>
            <label class="form-card__field">
              {{ 'interaction_rules.form.description_label' | translate }}
              <textarea name="description" [(ngModel)]="control.formData.description"></textarea>
            </label>
            <label class="form-card__field">
              {{ 'interaction_rules.form.region_label' | translate }}
              <input name="region" [(ngModel)]="control.formData.region" />
            </label>
            <div class="form-card__actions">
              <button type="submit" class="btn-primary" [disabled]="interactionRuleForm.invalid || control.saving">
                {{ 'interaction_rules.form.submit_update' | translate }}
              </button>
              <a [routerLink]="['/interaction_rules']" class="btn-secondary">{{ 'common.back' | translate }}</a>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrl: './interaction-rule-edit.component.css'
})
export class InteractionRuleEditComponent implements InteractionRuleEditView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly loadUseCase = inject(LoadInteractionRuleForEditUseCase);
  private readonly updateUseCase = inject(UpdateInteractionRuleUseCase);
  private readonly presenter = inject(InteractionRuleEditPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: InteractionRuleEditViewState = initialControl;
  get control(): InteractionRuleEditViewState {
    return this._control;
  }
  set control(value: InteractionRuleEditViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  private get interactionRuleId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.interactionRuleId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid interaction rule id.' };
      return;
    }
    this.loadUseCase.execute({ interactionRuleId: this.interactionRuleId });
  }

  updateInteractionRule(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    this.updateUseCase.execute({
      interactionRuleId: this.interactionRuleId,
      ...this.control.formData,
      onSuccess: () => this.router.navigate(['/interaction_rules', this.interactionRuleId])
    });
  }
}