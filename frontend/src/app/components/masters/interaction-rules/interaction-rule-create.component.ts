import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { InteractionRuleCreateView, InteractionRuleCreateViewState, InteractionRuleCreateFormData } from './interaction-rule-create.view';
import { CreateInteractionRuleUseCase } from '../../../usecase/interaction-rules/create-interaction-rule.usecase';
import {
  InteractionRuleCreatePresenter,
  INTERACTION_RULE_CREATE_PROVIDERS
} from '../../../usecase/interaction-rules/interaction-rule-create.providers';

const initialFormData: InteractionRuleCreateFormData = {
  rule_type: 'continuous_cultivation',
  source_group: '',
  target_group: '',
  impact_ratio: 0,
  is_directional: false,
  description: null,
  region: null
};

import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';

const initialControl: InteractionRuleCreateViewState = {
  saving: false,
  error: null,
  formData: initialFormData
,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-interaction-rule-create',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule, RegionSelectComponent, MasterContextHeaderComponent],
  providers: [...INTERACTION_RULE_CREATE_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'interaction_rules.new.title' | translate }}</h2>
        <form (ngSubmit)="createInteractionRule()" #interactionRuleForm="ngForm" class="form-card__form">
          <label class="form-card__field" for="rule_type">
            <span class="form-card__field-label">{{ 'interaction_rules.form.rule_type_label' | translate }}</span>
            <select id="rule_type" name="rule_type" [(ngModel)]="control.formData.rule_type" required>
              @for (code of ruleTypeCodes; track code) {
                <option [value]="code">{{ ruleTypeLabel(code) }}</option>
              }
            </select>
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
            <span class="form-card__field-label">{{ 'interaction_rules.form.direction_label' | translate }}</span>
            <input id="is_directional" name="is_directional" type="checkbox" [(ngModel)]="control.formData.is_directional" />
          </label>
          <label class="form-card__field" for="description">
            <span class="form-card__field-label">{{ 'interaction_rules.form.description_label' | translate }}</span>
            <textarea id="description" name="description" [(ngModel)]="control.formData.description"></textarea>
          </label>
          @if (auth.user()?.admin) {
            <app-region-select
              [region]="control.formData.region"
              (regionChange)="control.formData.region = $event">
            </app-region-select>
          }
          <div class="form-card__actions">
            <button type="submit" class="btn-primary" [disabled]="interactionRuleForm.invalid || control.saving">
              {{ 'interaction_rules.form.submit_create' | translate }}
            </button>
          </div>
        </form>
      </section>
    </main>
  `,
  styleUrls: ['./interaction-rule-create.component.css']
})
export class InteractionRuleCreateComponent implements InteractionRuleCreateView, OnInit {
  readonly auth = inject(AuthService);
  private readonly router = inject(Router);
  private readonly translate = inject(TranslateService);
  private readonly useCase = inject(CreateInteractionRuleUseCase);
  private readonly presenter = inject(InteractionRuleCreatePresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: InteractionRuleCreateViewState = initialControl;
  get control(): InteractionRuleCreateViewState {
    return this._control;
  }
  set control(value: InteractionRuleCreateViewState) {
    this._control = applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage });
    this.cdr.markForCheck();
  }

  get contextCrumbs(): MasterContextCrumb[] {
    return [
      { labelKey: 'interaction_rules.index.title', routerLink: ['/interaction_rules'] },
      { labelKey: 'interaction_rules.new.title' }
    ];
  }

  ngOnInit(): void {
    this.presenter.setView(this);
  }

  createInteractionRule(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    const region = this.resolveRegionForSubmit();
    this.useCase.execute({
      ...this.control.formData,
      region,
      onSuccess: () => this.router.navigate(['/interaction_rules'])
    });
  }

  private resolveRegionForSubmit(): string | null {
    const user = this.auth.user();
    if (user?.admin) {
      return this.control.formData.region ?? null;
    }
    return (user as { region?: string | null } | null)?.region ?? null;
  }

  readonly ruleTypeCodes = ['continuous_cultivation'] as const;

  ruleTypeLabel(code: string): string {
    const key = `interaction_rules.form.rule_type_codes.${code}`;
    const t = this.translate.instant(key);
    return t !== key ? t : code;
  }
}