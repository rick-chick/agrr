import { Component, DestroyRef, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { Channel } from 'actioncable';
import { TaskScheduleTimelineComponent } from './task-schedule-timeline.component';
import {
  TaskScheduleWeekNavComponent,
  type TaskScheduleViewMode
} from './task-schedule-week-nav.component';
import { PlanTaskScheduleView, PlanTaskScheduleViewState } from './plan-task-schedule.view';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { PlanTaskSchedulePresenter, PLAN_TASK_SCHEDULE_PROVIDERS } from '../../usecase/plans/plan-task-schedule.providers';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
import { TaskScheduleSyncBannerComponent } from './task-schedule-sync-banner.component';
import { RegenerateTaskScheduleUseCase } from '../../usecase/plans/regenerate-task-schedule.usecase';
import { SubscribeTaskScheduleSyncUseCase } from '../../usecase/plans/subscribe-task-schedule-sync.usecase';
import { FlashMessageService } from '../../services/flash-message.service';
import { applyTaskScheduleSyncViewEffects } from './task-schedule-sync-view.effects';
import { mergeCropBannerContext } from '../../adapters/plans/task-schedule-sync-presenter.helpers';
import { formatIsoDateForDisplay } from '../../core/format-display-date';

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
    TaskScheduleWeekNavComponent,
    TranslateModule,
    RouterLink,
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
          @if (fieldCultivationFilterId) {
            <nav class="plan-task-schedule__filter-nav" aria-label="Field filter navigation">
              <a
                class="plan-task-schedule__filter-link"
                [routerLink]="['/plans', planId, 'task_schedule']"
              >
                {{ 'plans.task_schedules.view_all_fields' | translate }}
              </a>
              <a class="plan-task-schedule__filter-link" [routerLink]="['/plans', planId]">
                {{ 'plans.task_schedules.back_to_planting_plan' | translate }}
              </a>
            </nav>
          }
          @if (scheduleIsEmpty) {
            @if (
              syncState === 'generating' ||
              syncState === 'failed' ||
              syncState === 'never' ||
              syncState === 'stale'
            ) {
              <app-task-schedule-sync-banner
                [syncState]="syncState"
                [syncError]="control.schedule.plan.task_schedule_sync_error"
                [syncErrorCropId]="control.schedule.plan.task_schedule_sync_error_crop_id"
                [cropIds]="cropIdsForBanner"
                [cropNames]="cropNamesForBanner"
                [planId]="planId"
                returnTab="task_schedule"
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
              @if (syncState !== 'generating' && emptyHintKey) {
                <p class="plan-work__empty-hint">{{ emptyHintKey | translate }}</p>
              }
            </div>
          } @else {
            <app-task-schedule-sync-banner
              [syncState]="syncState"
              [syncError]="control.schedule.plan.task_schedule_sync_error"
              [syncErrorCropId]="control.schedule.plan.task_schedule_sync_error_crop_id"
              [cropIds]="cropIdsForBanner"
              [cropNames]="cropNamesForBanner"
              [planId]="planId"
              returnTab="task_schedule"
              [regenerating]="control.regenerating"
              [regenerateError]="control.regenerateError"
              (retry)="regenerateTaskSchedule()"
            />
            <div class="plan-task-schedule__toolbar">
              <app-task-schedule-week-nav
                [viewMode]="viewMode"
                [week]="control.schedule.week"
                [minimap]="control.schedule.minimap"
                (viewModeChange)="onViewModeChange($event)"
                (weekChange)="onWeekChange($event)"
                (weekToday)="onWeekToday()"
              />
              <div class="plan-task-schedule__meta">
                <p class="plan-task-schedule__generated-at">{{ timelineGeneratedAtLabel }}</p>
                <p class="plan-task-schedule__summary">{{
                  'plans.task_schedules.summary'
                    | translate: { fields: fieldCount, tasks: taskCount }
                }}</p>
              </div>
            </div>
            @if (syncState === 'ready') {
              <details class="plan-task-schedule__regenerate-details">
                <summary>{{ 'plans.task_schedules.sync_retry' | translate }}</summary>
                <div class="plan-task-schedule__regenerate-body">
                  @if (control.regenerateError) {
                    <p class="plan-task-schedule__regenerate-error" role="alert">
                      {{ control.regenerateError | translate }}
                    </p>
                  }
                  <button
                    type="button"
                    class="btn-secondary plan-task-schedule__regenerate-button"
                    [disabled]="control.regenerating"
                    (click)="regenerateTaskSchedule()"
                  >
                    {{
                      (control.regenerating
                        ? 'common.loading'
                        : 'plans.task_schedules.sync_retry') | translate
                    }}
                  </button>
                </div>
              </details>
            }
            <app-task-schedule-timeline
              [fields]="control.schedule.fields"
              [planId]="planId"
            />
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
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  private syncChannel: Channel | null = null;

  viewMode: TaskScheduleViewMode = 'plan';
  currentWeekStart: string | null = null;

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get fieldCultivationFilterId(): number | null {
    const raw = this.route.snapshot.queryParamMap.get('field_cultivation_id');
    if (!raw) {
      return null;
    }
    const parsed = Number(raw);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }

  get scheduleIsEmpty(): boolean {
    return (this.control.schedule?.fields.length ?? 0) === 0;
  }

  get fieldCount(): number {
    return this.control.schedule?.fields.length ?? 0;
  }

  get taskCount(): number {
    return (this.control.schedule?.fields ?? []).reduce(
      (sum, field) =>
        sum + field.schedules.general.length + field.schedules.fertilizer.length,
      0
    );
  }

  get timelineGeneratedAtLabel(): string {
    const plan = this.control.schedule?.plan;
    if (!plan) {
      return this.translate.instant('plans.task_schedules.timeline_generated_unknown');
    }
    const datetime =
      plan.timeline_generated_at_display ||
      (plan.timeline_generated_at
        ? formatIsoDateForDisplay(plan.timeline_generated_at, this.translate.currentLang)
        : null);
    if (!datetime) {
      return this.translate.instant('plans.task_schedules.timeline_generated_unknown');
    }
    return this.translate.instant('plans.task_schedules.timeline_generated_at', { datetime });
  }

  get syncState(): string {
    return this.control.schedule?.plan.task_schedule_sync_state ?? '';
  }

  get emptyHintKey(): string | null {
    if (this.syncState === 'generating' || this.syncState === 'failed') {
      return null;
    }
    if (this.syncState === 'ready') {
      return 'plans.task_schedules.empty_ready_no_fields';
    }
    return 'plans.task_schedules.empty_hint';
  }

  private get cropBannerContext(): ReturnType<typeof mergeCropBannerContext> {
    return mergeCropBannerContext(
      this.control.schedule?.fields ?? [],
      this.control.schedule?.plan?.remediation_crops
    );
  }

  get cropIdsForBanner(): number[] {
    return this.cropBannerContext.cropIds;
  }

  get cropNamesForBanner(): Record<number, string> {
    return this.cropBannerContext.cropNames;
  }

  private _control: PlanTaskScheduleViewState = initialControl;
  get control(): PlanTaskScheduleViewState {
    return this._control;
  }
  set control(value: PlanTaskScheduleViewState) {
    const wasLoading = this._control.loading;
    this._control = applyTaskScheduleSyncViewEffects(this._control, value, {
      flash: this.flashMessage,
      onReload: () => this.reload({ silent: true })
    });
    if (
      wasLoading &&
      !this._control.loading &&
      this.viewMode === 'week' &&
      this._control.schedule?.week?.start_date
    ) {
      this.currentWeekStart = this._control.schedule.week.start_date;
    }
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
    this.useCase.execute({
      planId,
      scope: this.viewMode,
      ...(this.viewMode === 'week' && this.currentWeekStart
        ? { weekStart: this.currentWeekStart }
        : {}),
      ...(this.fieldCultivationFilterId != null
        ? { fieldCultivationId: this.fieldCultivationFilterId }
        : {})
    });
  }

  onViewModeChange(mode: TaskScheduleViewMode): void {
    if (this.viewMode === mode) {
      return;
    }
    this.viewMode = mode;
    if (mode === 'plan') {
      this.currentWeekStart = null;
    } else if (!this.currentWeekStart && this.control.schedule?.week?.start_date) {
      this.currentWeekStart = this.control.schedule.week.start_date;
    }
    this.reload();
  }

  onWeekChange(weekStart: string): void {
    if (this.currentWeekStart === weekStart) {
      return;
    }
    this.currentWeekStart = weekStart;
    this.viewMode = 'week';
    this.reload();
  }

  onWeekToday(): void {
    this.viewMode = 'week';
    this.currentWeekStart = null;
    this.reload();
  }

  regenerateTaskSchedule(): void {
    this.regenerateUseCase.execute({ planId: this.planId });
  }
}
