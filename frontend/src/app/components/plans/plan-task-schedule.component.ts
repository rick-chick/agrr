import { Component, DestroyRef, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { Channel } from 'actioncable';
import { TaskScheduleTimelineComponent } from './task-schedule-timeline.component';
import { PlanTaskScheduleView, PlanTaskScheduleViewState } from './plan-task-schedule.view';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { PlanTaskSchedulePresenter, PLAN_TASK_SCHEDULE_PROVIDERS } from '../../usecase/plans/plan-task-schedule.providers';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
import { TaskScheduleSyncBannerComponent } from './task-schedule-sync-banner.component';
import { RegenerateTaskScheduleUseCase } from '../../usecase/plans/regenerate-task-schedule.usecase';
import { SubscribeTaskScheduleSyncUseCase } from '../../usecase/plans/subscribe-task-schedule-sync.usecase';
import { FlashMessageService } from '../../services/flash-message.service';
import { applyTaskScheduleSyncViewEffects } from './task-schedule-sync-view.effects';

const initialControl: PlanTaskScheduleViewState = {
  loading: true,
  error: null,
  schedule: null,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  syncReloadNonce: 0
};

@Component({
  selector: 'app-plan-task-schedule',
  standalone: true,
  imports: [
    CommonModule,
    TaskScheduleTimelineComponent,
    TranslateModule,
    PlanPlanContextHeaderComponent,
    TaskScheduleSyncBannerComponent
  ],
  providers: [...PLAN_TASK_SCHEDULE_PROVIDERS],
  template: `
    <main class="page-main page-main--fit">
      <app-plan-plan-context-header
        [planId]="planId"
        [planName]="control.schedule?.plan?.name ?? null"
        pageTitleKey="plans.task_schedules.page_title"
      />

      <section class="section-card" aria-labelledby="plan-context-page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error plan-work__error" role="alert">
            <p>{{ control.error | translate }}</p>
            <button type="button" class="btn-secondary plan-work__retry" (click)="reload()">
              {{ 'plans.work.retry' | translate }}
            </button>
          </div>
        } @else if (control.schedule) {
          @if (scheduleIsEmpty) {
            @if (syncState === 'generating') {
              <app-task-schedule-sync-banner
                [syncState]="syncState"
                [syncError]="control.schedule.plan.task_schedule_sync_error"
                [regenerating]="control.regenerating"
                [regenerateError]="control.regenerateError"
                (retry)="regenerateTaskSchedule()"
              />
            }
            <div class="plan-work__empty">
              <p class="plan-work__empty-message">
                @if (syncState === 'generating') {
                  {{ 'plans.task_schedules.sync_generating' | translate }}
                } @else {
                  {{ 'plans.task_schedules.no_schedules' | translate }}
                }
              </p>
              @if (syncState !== 'generating') {
                <p class="plan-work__empty-hint">{{ 'plans.task_schedules.empty_hint' | translate }}</p>
              }
              @if (showEmptyRegenerate) {
                <button
                  type="button"
                  class="btn-primary plan-work__empty-cta plan-work__cta--constrained"
                  [disabled]="control.regenerating"
                  (click)="regenerateTaskSchedule()"
                >
                  {{
                    (control.regenerating ? 'common.loading' : 'plans.task_schedules.sync_retry')
                      | translate
                  }}
                </button>
              }
            </div>
          } @else {
            <app-task-schedule-sync-banner
              [syncState]="syncState"
              [syncError]="control.schedule.plan.task_schedule_sync_error"
              [regenerating]="control.regenerating"
              [regenerateError]="control.regenerateError"
              (retry)="regenerateTaskSchedule()"
            />
            <app-task-schedule-timeline [fields]="control.schedule.fields" />
          }
        }
      </section>
    </main>
  `,
  styleUrls: ['./plan-task-schedule.component.css']
})
export class PlanTaskScheduleComponent implements PlanTaskScheduleView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly useCase = inject(LoadPlanTaskScheduleUseCase);
  private readonly regenerateUseCase = inject(RegenerateTaskScheduleUseCase);
  private readonly subscribeSyncUseCase = inject(SubscribeTaskScheduleSyncUseCase);
  private readonly presenter = inject(PlanTaskSchedulePresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  private syncChannel: Channel | null = null;

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get scheduleIsEmpty(): boolean {
    return (this.control.schedule?.fields.length ?? 0) === 0;
  }

  get syncState(): string {
    return this.control.schedule?.plan.task_schedule_sync_state ?? '';
  }

  get showEmptyRegenerate(): boolean {
    return this.syncState === 'never' || this.syncState === 'failed' || this.syncState === 'stale';
  }

  private _control: PlanTaskScheduleViewState = initialControl;
  get control(): PlanTaskScheduleViewState {
    return this._control;
  }
  set control(value: PlanTaskScheduleViewState) {
    this._control = applyTaskScheduleSyncViewEffects(this._control, value, {
      flash: this.flashMessage,
      onReload: () => this.reload({ silent: true })
    });
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.destroyRef.onDestroy(() => {
      this.syncChannel?.unsubscribe();
    });
    const planId = this.planId;
    if (!planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    this.subscribeSyncUseCase.execute({
      planId,
      onSubscribed: (channel) => {
        this.syncChannel = channel;
      }
    });
    this.reload();
  }

  reload(options?: { silent?: boolean }): void {
    const planId = this.planId;
    if (!planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    if (!options?.silent) {
      this.control = { ...this.control, loading: true, error: null, regenerateError: null };
    }
    this.useCase.execute({ planId });
  }

  regenerateTaskSchedule(): void {
    this.regenerateUseCase.execute({ planId: this.planId });
  }
}
