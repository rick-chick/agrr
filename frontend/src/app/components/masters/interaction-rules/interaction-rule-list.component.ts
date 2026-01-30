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
    <main class="page-main">
      <header class="page-header">
        <h1 class="page-title">{{ 'interaction_rules.index.title' | translate }}</h1>
        <p class="page-description">{{ 'interaction_rules.index.description' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="section-list-heading">
        <h2 id="section-list-heading" class="section-title">{{ 'interaction_rules.index.list_heading' | translate }}</h2>
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <a [routerLink]="['/interaction_rules', 'new']" class="btn-primary">{{ 'interaction_rules.index.new_rule' | translate }}</a>
          <ul class="card-list" role="list">
            @for (rule of control.rules; track rule.id) {
              <li class="card-list__item">
                <a [routerLink]="['/interaction_rules', rule.id]" class="item-card">
                  <span class="item-card__title">{{ rule.source_group }} → {{ rule.target_group }}</span>
                  <span class="item-card__meta">{{ rule.rule_type }} ({{ rule.impact_ratio }})</span>
                </a>
                <div class="list-item-actions">
                  <a [routerLink]="['/interaction_rules', rule.id, 'edit']" class="btn-secondary btn-sm">{{ 'common.edit' | translate }}</a>
                  <button type="button" class="btn-danger btn-sm" (click)="deleteInteractionRule(rule.id)">
                    {{ 'common.delete' | translate }}
                  </button>
                </div>
              </li>
            }
          </ul>
        }
      </section>
    </main>
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
