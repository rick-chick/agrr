import { Component, OnInit, inject, ChangeDetectorRef, ElementRef, ViewChild, signal } from '@angular/core';
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
import { PublicPlanStore } from '../../services/public-plans/public-plan-store.service';
import { applyPendingUndoToastViewEffects } from '../../core/view-effects/pending-undo-toast-view.effects';
import { applyPendingErrorFlashViewEffects } from '../../core/view-effects/pending-error-flash-view.effects';
import { CardListSkeletonComponent } from '../shared/skeleton/card-list-skeleton.component';
import { buildPlanListFarmGroups } from '../../domain/plans/build-plan-list-farm-groups';
import type { PlanListFarmGroup } from '../../domain/plans/plan-list-farm-group';

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
        } @else if (control.plans.length === 0) {
          <div class="plan-list-empty">
            <p>{{ 'plans.index.no_plans' | translate }}</p>
            <p class="plan-list-empty-hint">{{ 'plans.index.no_plans_hint' | translate }}</p>
            <a routerLink="/plans/new" class="btn btn-primary">{{ 'plans.index.new_plan' | translate }}</a>
            <p class="plan-list-empty-secondary">
              <a routerLink="/public-plans/new">{{ 'plans.index.try_public_plans' | translate }}</a>
            </p>
            @if (publicPlanHandoffPlanId; as handoffPlanId) {
              <p class="plan-list-empty-public-handoff">
                <a [routerLink]="['/public-plans/results']" [queryParams]="{ planId: handoffPlanId }">
                  {{ 'plans.index.continue_public_plan' | translate }}
                </a>
              </p>
            }
          </div>
        } @else {
          <div class="section-card__header-actions">
            <a routerLink="/plans/new" class="btn btn-primary">{{ 'plans.index.new_plan' | translate }}</a>
          </div>
          @for (group of farmGroups(); track group.farmId) {
            <section class="plan-list__farm-group" [attr.aria-labelledby]="'plan-list-farm-' + group.farmId">
              <header class="plan-list__farm-group-header">
                <div class="plan-list__farm-group-heading">
                  <button
                    type="button"
                    class="btn-link plan-list__farm-group-toggle"
                    (click)="toggleFarmGroup(group.farmId)"
                    [attr.aria-expanded]="isFarmGroupExpanded(group.farmId)"
                    [attr.aria-controls]="'plan-list-farm-plans-' + group.farmId"
                  >
                    {{
                      isFarmGroupExpanded(group.farmId)
                        ? ('plans.index.farm_group.collapse' | translate)
                        : ('plans.index.farm_group.expand' | translate)
                    }}
                  </button>
                  <h2 id="plan-list-farm-{{ group.farmId }}" class="plan-list__farm-group-title">
                    {{ group.farmName }}
                  </h2>
                </div>
                <a
                  class="btn btn-secondary plan-list__variance-link"
                  routerLink="/work/variance"
                  [queryParams]="{ farm_id: group.farmId }"
                >
                  {{ 'plans.index.farm_group.compare_variance' | translate }}
                </a>
              </header>
              @if (isFarmGroupExpanded(group.farmId)) {
                <ul
                  id="plan-list-farm-plans-{{ group.farmId }}"
                  class="card-list"
                  role="list"
                >
                  @for (plan of group.plans; track plan.id) {
                    <li class="card-list__item">
                      <article class="item-card">
                        <a [routerLink]="['/plans', plan.id]" class="item-card__body">
                          <span class="item-card__title">{{ plan.name | planDisplayName }}</span>
                          <span class="plan-list__plan-meta">
                            @if (plan.plan_year != null) {
                              <span class="plan-list__plan-year">
                                {{ 'plans.index.year_label' | translate: { year: plan.plan_year } }}
                              </span>
                            }
                            @if (plan.status) {
                              <span class="plan-list__plan-status">
                                {{ planStatusKey(plan.status) | translate }}
                              </span>
                            }
                          </span>
                          @if (plan.inputGap) {
                            <span class="plan-list__gap-summary">
                              {{
                                'plans.index.input_gap.unrecorded_summary'
                                  | translate: { count: plan.inputGap.unrecordedCount }
                              }}
                              ·
                              {{
                                'plans.index.input_gap.action_required_summary'
                                  | translate: { count: plan.inputGap.actionRequiredCount }
                              }}
                              @if (plan.inputGap.amountVarianceCount > 0) {
                                ·
                                {{
                                  'plans.index.input_gap.amount_variance_summary'
                                    | translate: { count: plan.inputGap.amountVarianceCount }
                                }}
                              }
                            </span>
                          }
                        </a>
                        <div class="item-card__actions">
                          <a
                            [routerLink]="['/plans', plan.id, 'work']"
                            class="btn btn-secondary plan-list__work-link"
                          >
                            {{ 'plans.index.input_gap.work_link' | translate }}
                          </a>
                          <a
                            [routerLink]="['/plans', plan.id, 'learn']"
                            class="btn btn-secondary plan-list__learn-link"
                          >
                            {{ 'plans.index.input_gap.learn_link' | translate }}
                          </a>
                          <a [routerLink]="['/plans', plan.id]" class="btn btn-secondary">
                            {{ 'common.show' | translate }}
                          </a>
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
          }
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
  private readonly publicPlanStore = inject(PublicPlanStore);
  private readonly cdr = inject(ChangeDetectorRef);

  @ViewChild('deleteConfirmDialog') deleteConfirmDialogRef?: ElementRef<HTMLDialogElement>;

  pendingDeletePlanId: number | null = null;

  get publicPlanHandoffPlanId(): number | null {
    const planId = this.publicPlanStore.state.planId;
    return planId && planId > 0 ? planId : null;
  }

  private readonly collapsedFarmGroupIds = signal<ReadonlySet<number>>(new Set());

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

  farmGroups(): PlanListFarmGroup[] {
    return buildPlanListFarmGroups(this.control.plans);
  }

  isFarmGroupExpanded(farmId: number): boolean {
    return !this.collapsedFarmGroupIds().has(farmId);
  }

  toggleFarmGroup(farmId: number): void {
    this.collapsedFarmGroupIds.update((collapsed) => {
      const next = new Set(collapsed);
      if (next.has(farmId)) {
        next.delete(farmId);
      } else {
        next.add(farmId);
      }
      return next;
    });
  }

  planStatusKey(status: string): string {
    return `plans.index.status.${status}`;
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
