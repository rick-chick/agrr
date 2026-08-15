import { Component, OnInit, inject, ChangeDetectorRef, ElementRef, ViewChild } from '@angular/core';
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
import { CardListSkeletonComponent } from '../shared/skeleton/card-list-skeleton.component';

const initialControl: PlanListViewState = {
  loading: true,
  error: null,
  entries: [],
  pendingUndoToast: null,
  pendingErrorFlash: null
};

@Component({
  selector: 'app-plan-list',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, PlanDisplayNamePipe, CardListSkeletonComponent],
  providers: [...PLAN_LIST_PROVIDERS],
  template: `
    <div class="page-main">
      <header class="page-header">
        <h1 id="page-title" class="page-title">{{ 'plans.index.title' | translate }}</h1>
        <p class="page-description">{{ 'plans.index.description' | translate }}</p>
      </header>
      <section class="section-card" aria-labelledby="page-title">
        @if (control.loading) {
          <app-card-list-skeleton class="list-loading-skeleton" />
          <p class="master-loading list-loading-text">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error plan-list__error" role="alert">
            <p>{{ control.error | translate }}</p>
            <button type="button" class="btn btn-secondary plan-list__retry" (click)="load()">
              {{ 'plans.index.retry' | translate }}
            </button>
          </div>
        } @else if (control.entries.length === 0) {
          <div class="plan-list-empty">
            <p>{{ 'plans.index.no_plans' | translate }}</p>
            <p class="plan-list-empty-hint">{{ 'plans.index.no_plans_hint' | translate }}</p>
            <a routerLink="/plans/new" class="btn btn-primary">{{ 'plans.index.new_plan' | translate }}</a>
            <p class="plan-list-empty-secondary">
              <a routerLink="/public-plans/new">{{ 'plans.index.try_public_plans' | translate }}</a>
            </p>
          </div>
        } @else {
          <div class="section-card__header-actions">
            <a routerLink="/plans/new" class="btn btn-primary">{{ 'plans.index.new_plan' | translate }}</a>
          </div>
          <ul class="card-list" role="list">
            @for (entry of control.entries; track entry.plan.id) {
              <li class="card-list__item">
                <article class="item-card">
                  <div class="item-card__body">
                    <a [routerLink]="['/plans', entry.plan.id]" class="item-card__title-link">
                      <span class="item-card__title">{{ entry.plan.name | planDisplayName }}</span>
                    </a>
                    @if (entry.inputGap) {
                      <dl class="plan-list__input-gap" aria-label="{{ 'plans.index.plan_card.input_gap_label' | translate }}">
                        <div>
                          <dt>{{ 'plans.learn.input_gap.unrecorded' | translate }}</dt>
                          <dd>{{ entry.inputGap.unrecordedCount }}</dd>
                        </div>
                        <div>
                          <dt>{{ 'plans.learn.input_gap.action_required' | translate }}</dt>
                          <dd>{{ entry.inputGap.actionRequiredCount }}</dd>
                        </div>
                      </dl>
                      @if (entry.inputGap.unrecordedCount > 0 || entry.inputGap.actionRequiredCount > 0) {
                        <div class="plan-list__input-gap-links">
                          @if (entry.inputGap.unrecordedCount > 0) {
                            <a
                              class="plan-list__work-link"
                              [routerLink]="['/plans', entry.plan.id, 'work']"
                            >
                              {{ 'plans.index.plan_card.work_link' | translate }}
                            </a>
                          }
                          @if (entry.inputGap.actionRequiredCount > 0) {
                            <a
                              class="plan-list__learn-link"
                              [routerLink]="['/plans', entry.plan.id, 'learn']"
                            >
                              {{ 'plans.index.plan_card.learn_link' | translate }}
                            </a>
                          }
                        </div>
                      }
                    }
                  </div>
                  <div class="item-card__actions">
                    <a [routerLink]="['/plans', entry.plan.id]" class="btn btn-secondary">
                      {{ 'common.show' | translate }}
                    </a>
                    <button
                      type="button"
                      class="btn btn-danger"
                      (click)="deletePlan(entry.plan.id)"
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
    </div>

    <dialog
      #deleteConfirmDialog
      class="confirm-dialog plan-list__delete-confirm"
      (cancel)="cancelDeleteConfirmDialog($event)"
      (click)="onDeleteConfirmDialogBackdropClick($event)"
    >
      @if (pendingDeletePlanId != null) {
        <p class="confirm-dialog__message">{{ 'plans.index.delete_confirm_message' | translate }}</p>
        <div class="confirm-dialog__actions">
          <button type="button" class="btn btn-secondary" (click)="cancelDeleteConfirmDialog()">
            {{ 'common.cancel' | translate }}
          </button>
          <button type="button" class="btn btn-danger" (click)="confirmDeletePlan()">
            {{ 'common.delete' | translate }}
          </button>
        </div>
      }
    </dialog>

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

  @ViewChild('deleteConfirmDialog') deleteConfirmDialogRef?: ElementRef<HTMLDialogElement>;

  pendingDeletePlanId: number | null = null;

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
    this.pendingDeletePlanId = planId;
    this.deleteConfirmDialogRef?.nativeElement?.showModal();
  }

  confirmDeletePlan(): void {
    if (this.pendingDeletePlanId == null) {
      return;
    }
    const planId = this.pendingDeletePlanId;
    this.pendingDeletePlanId = null;
    this.deleteConfirmDialogRef?.nativeElement?.close();
    this.deleteUseCase.execute({
      planId,
      onAfterUndo: () => this.refreshAfterUndo()
    });
  }

  cancelDeleteConfirmDialog(event?: Event): void {
    event?.preventDefault();
    this.pendingDeletePlanId = null;
    this.deleteConfirmDialogRef?.nativeElement?.close();
  }

  onDeleteConfirmDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.deleteConfirmDialogRef?.nativeElement) {
      this.cancelDeleteConfirmDialog();
    }
  }
}
