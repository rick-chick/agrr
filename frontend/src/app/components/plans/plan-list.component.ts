import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { PlanListView, PlanListViewState } from './plan-list.view';
import { LoadPlanListUseCase } from '../../usecase/plans/load-plan-list.usecase';
import { PlanListPresenter } from '../../adapters/plans/plan-list.presenter';
import { LOAD_PLAN_LIST_OUTPUT_PORT } from '../../usecase/plans/load-plan-list.output-port';
import { PLAN_GATEWAY } from '../../usecase/plans/plan-gateway';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';

const initialControl: PlanListViewState = {
  loading: true,
  error: null,
  plans: []
};

@Component({
  selector: 'app-plan-list',
  standalone: true,
  imports: [CommonModule, RouterLink],
  providers: [
    PlanListPresenter,
    LoadPlanListUseCase,
    { provide: LOAD_PLAN_LIST_OUTPUT_PORT, useExisting: PlanListPresenter },
    { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
  ],
  template: `
    <section class="page">
      <h2>Plans</h2>
      @if (control.loading) {
        <p>Loading...</p>
      } @else if (control.error) {
        <p class="error">{{ control.error }}</p>
      } @else {
        <ul>
          <li *ngFor="let plan of control.plans">
            <a [routerLink]="['/plans', plan.id]">{{ plan.name }}</a>
            <span class="status">{{ plan.status ?? '-' }}</span>
          </li>
        </ul>
      }
    </section>
  `,
  styleUrl: './plan-list.component.css'
})
export class PlanListComponent implements PlanListView, OnInit {
  private readonly useCase = inject(LoadPlanListUseCase);
  private readonly presenter = inject(PlanListPresenter);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PlanListViewState = initialControl;
  get control(): PlanListViewState {
    return this._control;
  }
  set control(value: PlanListViewState) {
    this._control = value;
    this.cdr.markForCheck();
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
