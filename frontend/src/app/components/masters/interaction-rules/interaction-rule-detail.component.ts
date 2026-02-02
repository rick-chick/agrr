import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { InteractionRuleDetailView, InteractionRuleDetailViewState } from './interaction-rule-detail.view';
import { LoadInteractionRuleDetailUseCase } from '../../../usecase/interaction-rules/load-interaction-rule-detail.usecase';
import { DeleteInteractionRuleUseCase } from '../../../usecase/interaction-rules/delete-interaction-rule.usecase';
import { InteractionRuleDetailPresenter } from '../../../adapters/interaction-rules/interaction-rule-detail.presenter';
import { LOAD_INTERACTION_RULE_DETAIL_OUTPUT_PORT } from '../../../usecase/interaction-rules/load-interaction-rule-detail.output-port';
import { DELETE_INTERACTION_RULE_OUTPUT_PORT } from '../../../usecase/interaction-rules/delete-interaction-rule.output-port';
import { INTERACTION_RULE_GATEWAY } from '../../../usecase/interaction-rules/interaction-rule-gateway';
import { InteractionRuleApiGateway } from '../../../adapters/interaction-rules/interaction-rule-api.gateway';

const initialControl: InteractionRuleDetailViewState = {
  loading: true,
  error: null,
  rule: null
};

@Component({
  selector: 'app-interaction-rule-detail',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [
    InteractionRuleDetailPresenter,
    LoadInteractionRuleDetailUseCase,
    DeleteInteractionRuleUseCase,
    { provide: LOAD_INTERACTION_RULE_DETAIL_OUTPUT_PORT, useExisting: InteractionRuleDetailPresenter },
    { provide: DELETE_INTERACTION_RULE_OUTPUT_PORT, useExisting: InteractionRuleDetailPresenter },
    { provide: INTERACTION_RULE_GATEWAY, useClass: InteractionRuleApiGateway }
  ],
  template: `
    <main class="page-main">
      @if (control.loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (control.rule) {
        <section class="detail-card" aria-labelledby="detail-heading">
          <h1 id="detail-heading" class="detail-card__title">{{ control.rule.source_group }} → {{ control.rule.target_group }}</h1>
          <dl class="detail-card__list">
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'interaction_rules.show.rule_type' | translate }}</dt>
              <dd class="detail-row__value">{{ control.rule.rule_type }}</dd>
            </div>
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'interaction_rules.show.source_group' | translate }}</dt>
              <dd class="detail-row__value">{{ control.rule.source_group }}</dd>
            </div>
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'interaction_rules.show.target_group' | translate }}</dt>
              <dd class="detail-row__value">{{ control.rule.target_group }}</dd>
            </div>
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'interaction_rules.show.impact_ratio' | translate }}</dt>
              <dd class="detail-row__value">{{ control.rule.impact_ratio }}</dd>
            </div>
            <div class="detail-row">
              <dt class="detail-row__term">{{ 'interaction_rules.show.is_directional' | translate }}</dt>
              <dd class="detail-row__value">{{ control.rule.is_directional ? 'Yes' : 'No' }}</dd>
            </div>
            @if (control.rule.description) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'interaction_rules.show.description' | translate }}</dt>
                <dd class="detail-row__value">{{ control.rule.description }}</dd>
              </div>
            }
            @if (control.rule.region) {
              <div class="detail-row">
                <dt class="detail-row__term">{{ 'interaction_rules.show.region' | translate }}</dt>
                <dd class="detail-row__value">{{ control.rule.region }}</dd>
              </div>
            }
          </dl>
          <div class="detail-card__actions">
            <a [routerLink]="['/interaction_rules', control.rule.id, 'edit']" class="btn-primary">{{ 'common.edit' | translate }}</a>
            <a [routerLink]="['/interaction_rules']" class="btn-secondary">{{ 'common.back' | translate }}</a>
            <button type="button" class="btn-danger" (click)="deleteInteractionRule()">{{ 'common.delete' | translate }}</button>
          </div>
        </section>
      }
    </main>
  `,
  styleUrls: ['./interaction-rule-detail.component.css']
})
export class InteractionRuleDetailComponent implements InteractionRuleDetailView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadInteractionRuleDetailUseCase);
  private readonly deleteUseCase = inject(DeleteInteractionRuleUseCase);
  private readonly presenter = inject(InteractionRuleDetailPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: InteractionRuleDetailViewState = initialControl;
  get control(): InteractionRuleDetailViewState {
    return this._control;
  }
  set control(value: InteractionRuleDetailViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    const interactionRuleId = Number(this.route.snapshot.paramMap.get('id'));
    if (!interactionRuleId) {
      this.control = { ...initialControl, loading: false, error: 'Invalid interaction rule id.' };
      return;
    }
    this.load(interactionRuleId);
  }

  load(interactionRuleId: number): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute({ interactionRuleId });
  }

  reload(): void {
    const interactionRuleId = Number(this.route.snapshot.paramMap.get('id'));
    if (interactionRuleId) this.load(interactionRuleId);
  }

  deleteInteractionRule(): void {
    if (!this.control.rule) return;
    this.deleteUseCase.execute({
      interactionRuleId: this.control.rule.id,
      onSuccess: () => this.router.navigate(['/interaction_rules'])
    });
  }
}