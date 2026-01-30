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
    <div class="content-card">
      <div class="page-header">
        <a [routerLink]="['/interaction_rules']" class="btn btn-white">{{ 'common.back' | translate }}</a>
        @if (control.rule) {
          <a [routerLink]="['/interaction_rules', control.rule.id, 'edit']" class="btn btn-white">{{ 'common.edit' | translate }}</a>
          <button type="button" class="btn btn-danger" (click)="deleteInteractionRule()">{{ 'common.delete' | translate }}</button>
        }
      </div>

      @if (control.loading) {
        <p>{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else if (control.rule) {
        <h2 class="page-title">{{ control.rule.source_group }} → {{ control.rule.target_group }}</h2>
        <section class="info-section">
          <h3>{{ 'interaction_rules.show.rule_type' | translate }}</h3>
          <p>{{ control.rule.rule_type }}</p>
          <h3>{{ 'interaction_rules.show.source_group' | translate }}</h3>
          <p>{{ control.rule.source_group }}</p>
          <h3>{{ 'interaction_rules.show.target_group' | translate }}</h3>
          <p>{{ control.rule.target_group }}</p>
          <h3>{{ 'interaction_rules.show.impact_ratio' | translate }}</h3>
          <p>{{ control.rule.impact_ratio }}</p>
          <h3>{{ 'interaction_rules.show.is_directional' | translate }}</h3>
          <p>{{ control.rule.is_directional ? 'Yes' : 'No' }}</p>
          <h3 *ngIf="control.rule.description">{{ 'interaction_rules.show.description' | translate }}</h3>
          <p *ngIf="control.rule.description">{{ control.rule.description }}</p>
          <h3 *ngIf="control.rule.region">{{ 'interaction_rules.show.region' | translate }}</h3>
          <p *ngIf="control.rule.region">{{ control.rule.region }}</p>
        </section>
      }
    </div>
  `,
  styles: [`
    .info-section {
      margin-bottom: 2rem;
    }
  `]
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

  deleteInteractionRule(): void {
    if (!this.control.rule) return;
    this.deleteUseCase.execute({
      interactionRuleId: this.control.rule.id,
      onSuccess: () => this.router.navigate(['/interaction_rules'])
    });
  }
}