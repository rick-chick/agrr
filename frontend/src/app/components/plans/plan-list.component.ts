import { Component, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PlanDisplayNamePipe } from '../../core/plan-display-name.pipe';
import { PlanListView, PlanListViewState } from './plan-list.view';
import { LoadPlanListUseCase } from '../../usecase/plans/load-plan-list.usecase';
import { DeletePlanUseCase } from '../../usecase/plans/delete-plan.usecase';
import { PlanListPresenter, PLAN_LIST_PROVIDERS } from '../../usecase/plans/plan-list.providers';
import { UndoToastService } from '../../services/undo-toast.service';
import { FlashMessageService } from '../../services/flash-message.service';
import { applyPendingUndoToastViewEffects } from '../../core/view-effects/pending-undo-toast-view.effects';
import { applyPendingErrorFlashViewEffects } from '../../core/view-effects/pending-error-flash-view.effects';

const initialControl: PlanListViewState = {
  loading: true,
  error: null,
  plans: [],
  pendingUndoToast: null,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-plan-list',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, PlanDisplayNamePipe],
  providers: [...PLAN_LIST_PROVIDERS],
  template: `
    <main class="page-main">
      <header class="page-header page-header--with-action">
        <div>
          <h1 id="page-title" class="page-title">{{ 'plans.index.title' | translate }}</h1>
          <p class="page-description">{{ 'plans.index.subtitle' | translate }}</p>
        </div>
        <a routerLink="/plans/new" class="btn btn-primary">{{ 'plans.index.create_new' | translate }}</a>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <p class="plan-list-error">{{ control.error }}</p>
        } @else if (control.plans.length === 0) {
          <div class="plan-list-empty">
            <p>{{ 'plans.index.no_plans' | translate }}</p>
            <p class="plan-list-empty-hint">{{ 'plans.index.no_plans_hint' | translate }}</p>
            <a routerLink="/plans/new" class="btn btn-primary">{{ 'plans.index.create_new' | translate }}</a>
            <p class="plan-list-empty-secondary">
              <a routerLink="/public-plans/new">{{ 'plans.index.try_public_plans' | translate }}</a>
            </p>
          </div>
        } @else {
          <ul class="card-list" role="list">
            @for (plan of control.plans; track plan.id) {
              <li class="card-list__item">
                <article class="item-card">
                  <a [routerLink]="['/plans', plan.id]" class="item-card__body">
                    <span class="item-card__title">{{ plan.name | planDisplayName }}</span>
                  </a>
                  <div class="item-card__actions">
                    <button
                      type="button"
                      class="btn btn-danger"
                      (click)="deletePlan(plan.id)"
                      [attr.aria-label]="'common.delete' | translate"
                    >
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
  styleUrls: ['./plan-list.component.css']
})
export class PlanListComponent implements PlanListView, OnInit {
  private readonly loadUseCase = inject(LoadPlanListUseCase);
  private readonly deleteUseCase = inject(DeletePlanUseCase);
  private readonly presenter = inject(PlanListPresenter);
  private readonly undoToast = inject(UndoToastService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);

  private _control: PlanListViewState = initialControl;
  get control(): PlanListViewState {
    return this._control;
  }
  set control(value: PlanListViewState) {
    const next = applyPendingUndoToastViewEffects(
      applyPendingErrorFlashViewEffects(value, { flash: this.flashMessage }),
      { toast: this.undoToast }
    );
    this._control = next;
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
