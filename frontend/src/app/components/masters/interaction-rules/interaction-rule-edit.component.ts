import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { MasterContextHeaderComponent } from '../master-context-header/master-context-header.component';
import { MasterContextCrumb } from '../master-context-header/master-context-crumb';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { AuthService } from '../../../services/auth.service';
import { RegionSelectComponent } from '../../shared/region-select/region-select.component';
import { InteractionRuleEditView, InteractionRuleEditViewState, InteractionRuleEditFormData } from './interaction-rule-edit.view';
import { LoadInteractionRuleForEditUseCase } from '../../../usecase/interaction-rules/load-interaction-rule-for-edit.usecase';
import { UpdateInteractionRuleUseCase } from '../../../usecase/interaction-rules/update-interaction-rule.usecase';
import {
  InteractionRuleEditPresenter,
  INTERACTION_RULE_EDIT_PROVIDERS
} from '../../../usecase/interaction-rules/interaction-rule-edit.providers';

const initialFormData: InteractionRuleEditFormData = {
  rule_type: '',
  source_group: '',
  target_group: '',
  impact_ratio: 0,
  is_directional: false,
  description: null,
  region: null
};

import { FlashMessageService } from '../../../services/flash-message.service';
import { applyPendingErrorFlashViewEffects } from '../../../core/view-effects/pending-error-flash-view.effects';

const initialControl: InteractionRuleEditViewState = {
  loading: true,
  saving: false,
  error: null,
  formData: initialFormData
,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-interaction-rule-edit',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule, RegionSelectComponent, MasterContextHeaderComponent],
  providers: [...INTERACTION_RULE_EDIT_PROVIDERS],
  template: `
    <main class="page-main">
      <app-master-context-header [crumbs]="contextCrumbs" />
      <section class="form-card" aria-labelledby="form-heading">
        <h2 id="form-heading" class="form-card__title">{{ 'interaction_rules.edit.title' | translate }}</h2>
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <form (ngSubmit)="updateInteractionRule()" #interactionRuleForm="ngForm" class="form-card__form">
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
                (regionChange)="control.formData.region = $event"
              ></app-region-select>
            }
            <div class="form-card__actions">
              <button type="submit" class="btn btn-primary" [disabled]="interactionRuleForm.invalid || control.saving">
                {{ 'interaction_rules.form.submit_update' | translate }}
              </button>
            </div>
          </form>
        }
      </section>
    </main>
  `,
  styleUrls: ['./interaction-rule-edit.component.css']
})
export class InteractionRuleEditComponent implements InteractionRuleEditView, OnInit {
  readonly auth = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly translate = inject(TranslateService);
  private readonly loadUseCase = inject(LoadInteractionRuleForEditUseCase);
  private readonly updateUseCase = inject(UpdateInteractionRuleUseCase);
  private readonly presenter = inject(InteractionRuleEditPresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: InteractionRuleEditViewState = initialControl;
  get control(): InteractionRuleEditViewState {
    return this._control;
  }
  set control(value: InteractionRuleEditViewState) {
    this._control = applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage });
    this.cdr.markForCheck();
  }

  private get interactionRuleId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get contextCrumbs(): MasterContextCrumb[] {
    const crumbs: MasterContextCrumb[] = [
      { labelKey: 'interaction_rules.index.title', routerLink: ['/interaction_rules'] }
    ];
    const { source_group, target_group } = this.control.formData;
    if (!this.control.loading && source_group && target_group) {
      crumbs.push({
        label: `${source_group} → ${target_group}`,
        routerLink: ['/interaction_rules', this.interactionRuleId]
      });
    }
    crumbs.push({ labelKey: 'common.edit' });
    return crumbs;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    if (!this.interactionRuleId) {
      this.control = {
        ...initialControl,
        loading: false,
        error: this.translate.instant('interaction_rules.errors.invalid_id')
      };
      return;
    }
    this.loadUseCase.execute({ interactionRuleId: this.interactionRuleId });
  }

  updateInteractionRule(): void {
    if (this.control.saving) return;
    this.control = { ...this.control, saving: true, error: null };
    const region = this.resolveRegionForSubmit();
    this.updateUseCase.execute({
      interactionRuleId: this.interactionRuleId,
      ...this.control.formData,
      region,
      onSuccess: () => this.router.navigate(['/interaction_rules', this.interactionRuleId])
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