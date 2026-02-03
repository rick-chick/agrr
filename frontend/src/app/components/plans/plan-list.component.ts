import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { PlanListView, PlanListViewState } from './plan-list.view';
import { LoadPlanListUseCase } from '../../usecase/plans/load-plan-list.usecase';
import { DeletePlanUseCase } from '../../usecase/plans/delete-plan.usecase';
import { PlanListPresenter } from '../../adapters/plans/plan-list.presenter';
import { LOAD_PLAN_LIST_OUTPUT_PORT } from '../../usecase/plans/load-plan-list.output-port';
import { DELETE_PLAN_OUTPUT_PORT } from '../../usecase/plans/delete-plan.output-port';
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
    DeletePlanUseCase,
    { provide: LOAD_PLAN_LIST_OUTPUT_PORT, useExisting: PlanListPresenter },
    { provide: DELETE_PLAN_OUTPUT_PORT, useExisting: PlanListPresenter },
    { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
  ],
  template: `
    <main class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">Plans</h1>
        <p class="page-description">Manage your cultivation plans.</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        <div class="section-card__header-actions">
          <a routerLink="/plans/new" class="btn-primary">新規計画</a>
        </div>
        @if (control.loading) {
          <p class="master-loading">Loading...</p>
        } @else if (control.error) {
          <p class="plan-list-error">{{ control.error }}</p>
        } @else {
          <ul class="card-list" role="list">
            @for (plan of control.plans; track plan.id) {
              <li class="card-list__item">
                <article class="item-card">
                  <a [routerLink]="['/plans', plan.id]" class="item-card__body">
                    <span class="item-card__title">{{ plan.name }}</span>
                  </a>
                  <div class="item-card__actions">
                    <button
                      type="button"
                      class="btn-danger"
                      (click)="deletePlan(plan.id)"
                      aria-label="削除"
                    >
                      削除
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
  styleUrls: ['./plan-list.component.css']
})
export class PlanListComponent implements PlanListView, OnInit {
  private readonly loadUseCase = inject(LoadPlanListUseCase);
  private readonly deleteUseCase = inject(DeletePlanUseCase);
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
    this.loadUseCase.execute();
  }

  refreshAfterUndo(): void {
    this.loadUseCase.execute();
  }

  deletePlan(planId: number): void {
    this.deleteUseCase.execute({
      planId,
      onAfterUndo: () => this.refreshAfterUndo()
    });
  }
}
