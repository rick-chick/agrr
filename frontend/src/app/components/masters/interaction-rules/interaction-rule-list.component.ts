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
        <h1 id="page-title" class="page-title">{{ 'interaction_rules.index.title' | translate }}</h1>
        <p class="page-description">{{ 'interaction_rules.index.description' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else {
          <div class="section-card__header-actions">
            <a [routerLink]="['/interaction_rules', 'new']" class="btn-primary">{{ 'interaction_rules.index.new_rule' | translate }}</a>
          </div>
          <ul class="card-list" role="list">
            @for (rule of control.rules; track rule.id) {
              <li class="card-list__item">
                <article class="item-card">
                  <a [routerLink]="['/interaction_rules', rule.id]" class="item-card__body">
                    <span class="item-card__title">{{ rule.source_group }} → {{ rule.target_group }}</span>
                    <span class="item-card__meta">{{ rule.rule_type }} ({{ rule.impact_ratio }})</span>
                  </a>
                  <div class="item-card__actions">
                    <a [routerLink]="['/interaction_rules', rule.id, 'edit']" class="btn-secondary">{{ 'common.edit' | translate }}</a>
                    <button type="button" class="btn-danger" (click)="deleteInteractionRule(rule.id)" [attr.aria-label]="'common.delete' | translate">
                      {{ 'common.delete' | translate }}
                    </button>
                  </div>
                </article>
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

  /** UNDO 後の再取得。ローディング表示にせず一覧を更新する。 */
  refreshAfterUndo(): void {
    this.loadUseCase.execute();
  }

  deleteInteractionRule(interactionRuleId: number): void {
    this.deleteUseCase.execute({
      interactionRuleId,
      onSuccess: () => {},
      onAfterUndo: () => this.refreshAfterUndo()
    });
  }
}
