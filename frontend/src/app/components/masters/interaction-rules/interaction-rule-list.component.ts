import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import {
  InteractionRuleListView,
  InteractionRuleListViewState
} from './interaction-rule-list.view';
import { LoadInteractionRuleListUseCase } from '../../../usecase/interaction-rules/load-interaction-rule-list.usecase';
import { DeleteInteractionRuleUseCase } from '../../../usecase/interaction-rules/delete-interaction-rule.usecase';
import { InteractionRuleListPresenter } from '../../../adapters/interaction-rules/interaction-rule-list.presenter';
import { LOAD_INTERACTION_RULE_LIST_OUTPUT_PORT } from '../../../usecase/interaction-rules/load-interaction-rule-list.output-port';
import { DELETE_INTERACTION_RULE_OUTPUT_PORT } from '../../../usecase/interaction-rules/delete-interaction-rule.output-port';
import { INTERACTION_RULE_GATEWAY } from '../../../usecase/interaction-rules/interaction-rule-gateway';
import { InteractionRuleApiGateway } from '../../../adapters/interaction-rules/interaction-rule-api.gateway';

const initialControl: InteractionRuleListViewState = {
  loading: true,
  error: null,
  rules: []
};

@Component({
  selector: 'app-interaction-rule-list',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  providers: [
    InteractionRuleListPresenter,
    LoadInteractionRuleListUseCase,
    DeleteInteractionRuleUseCase,
    {
      provide: LOAD_INTERACTION_RULE_LIST_OUTPUT_PORT,
      useExisting: InteractionRuleListPresenter
    },
    {
      provide: DELETE_INTERACTION_RULE_OUTPUT_PORT,
      useExisting: InteractionRuleListPresenter
    },
    { provide: INTERACTION_RULE_GATEWAY, useClass: InteractionRuleApiGateway }
  ],
  template: `
    <section class="page">
      <h2>{{ 'interaction_rules.index.title' | translate }}</h2>
      <a [routerLink]="['/interaction_rules', 'new']" class="btn btn-primary">{{ 'interaction_rules.index.new_rule' | translate }}</a>
      @if (control.loading) {
        <p>{{ 'common.loading' | translate }}</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <div class="enhanced-grid">
          @for (rule of control.rules; track rule.id) {
            <div class="enhanced-selection-card-wrapper">
              <a [routerLink]="['/interaction_rules', rule.id]" class="enhanced-selection-card">
                <div class="enhanced-card-icon">🔄</div>
                <div class="enhanced-card-title">{{ rule.source_group }} → {{ rule.target_group }}</div>
                <div class="enhanced-card-subtitle">{{ rule.rule_type }} ({{ rule.impact_ratio }})</div>
              </a>
              <a [routerLink]="['/interaction_rules', rule.id, 'edit']" class="btn btn-sm">{{ 'common.edit' | translate }}</a>
              <button type="button" class="btn btn-sm btn-danger" (click)="deleteInteractionRule(rule.id)">
                {{ 'common.delete' | translate }}
              </button>
            </div>
          }
        </div>
      }
    </section>
  `,
  styleUrl: './interaction-rule-list.component.css'
})
export class InteractionRuleListComponent implements InteractionRuleListView, OnInit {
  private readonly loadUseCase = inject(LoadInteractionRuleListUseCase);
  private readonly deleteUseCase = inject(DeleteInteractionRuleUseCase);
  private readonly presenter = inject(InteractionRuleListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: InteractionRuleListViewState = initialControl;
  get control(): InteractionRuleListViewState {
    return this._control;
  }
  set control(value: InteractionRuleListViewState) {
    this._control = value;
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.load();
  }

  load(): void {
    this.control = { ...this.control, loading: true };
    this.loadUseCase.execute();
  }

  deleteInteractionRule(interactionRuleId: number): void {
    this.deleteUseCase.execute({
      interactionRuleId,
      onSuccess: () => {},
      onAfterUndo: () => this.load()
    });
  }
}
