import { Component, OnInit, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import {
  InteractionRuleListView,
  InteractionRuleListViewState
} from './interaction-rule-list.view';
import { LoadInteractionRuleListUseCase } from '../../../usecase/interaction-rules/load-interaction-rule-list.usecase';
import { InteractionRuleListPresenter } from '../../../adapters/interaction-rules/interaction-rule-list.presenter';
import { LOAD_INTERACTION_RULE_LIST_OUTPUT_PORT } from '../../../usecase/interaction-rules/load-interaction-rule-list.output-port';
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
  imports: [CommonModule],
  providers: [
    InteractionRuleListPresenter,
    LoadInteractionRuleListUseCase,
    {
      provide: LOAD_INTERACTION_RULE_LIST_OUTPUT_PORT,
      useExisting: InteractionRuleListPresenter
    },
    { provide: INTERACTION_RULE_GATEWAY, useClass: InteractionRuleApiGateway }
  ],
  template: `
    <section class="page">
      <h2>Interaction Rules</h2>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <ul>
          <li *ngFor="let item of control.rules">
            {{ item.rule_type }}: {{ item.source_group }} -> {{ item.target_group }} ({{ item.impact_ratio }})
          </li>
        </ul>
      }
    </section>
  `,
  styleUrl: './interaction-rule-list.component.css'
})
export class InteractionRuleListComponent implements InteractionRuleListView, OnInit {
  private readonly useCase = inject(LoadInteractionRuleListUseCase);
  private readonly presenter = inject(InteractionRuleListPresenter);

  private _control: InteractionRuleListViewState = initialControl;
  get control(): InteractionRuleListViewState {
    return this._control;
  }
  set control(value: InteractionRuleListViewState) {
    this._control = value;
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.load();
  }

  load(): void {
    this.control = { ...this.control, loading: true };
    this.useCase.execute();
  }
}
