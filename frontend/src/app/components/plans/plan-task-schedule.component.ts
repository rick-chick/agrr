import { Component, DestroyRef, OnInit, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { Channel } from 'actioncable';
import { TaskScheduleMonthListComponent } from './task-schedule-month-list.component';
import { PlanTaskScheduleView, PlanTaskScheduleViewState } from './plan-task-schedule.view';
import { LoadPlanTaskScheduleUseCase } from '../../usecase/plans/load-plan-task-schedule.usecase';
import { PlanTaskSchedulePresenter, PLAN_TASK_SCHEDULE_PROVIDERS } from '../../usecase/plans/plan-task-schedule.providers';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
import { TaskScheduleSyncBannerComponent } from './task-schedule-sync-banner.component';
import { RegenerateTaskScheduleUseCase } from '../../usecase/plans/regenerate-task-schedule.usecase';
import { SubscribeTaskScheduleSyncUseCase } from '../../usecase/plans/subscribe-task-schedule-sync.usecase';
import { FlashMessageService } from '../../services/flash-message.service';
import { applyTaskScheduleSyncViewEffects } from './task-schedule-sync-view.effects';
import { formatIsoDateForDisplay } from '../../core/format-display-date';
import { localTodayIso } from '../../core/local-today';

const ISO_DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

const initialControl: PlanTaskScheduleViewState = {
  loading: true,
  error: null,
  schedule: null,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  syncReloadNonce: 0,
  fromDate: localTodayIso(),
  fieldCultivationFilterId: null,
  monthGroups: [],
  fieldFilterOptions: [],
  cropIdsForBanner: [],
  cropNamesForBanner: {}
};

@Component({
  selector: 'app-plan-task-schedule',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    TaskScheduleMonthListComponent,
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
            <div class="plan-task-schedule__filters">
              <label class="plan-task-schedule__filter">
                <span class="plan-task-schedule__filter-label">{{
                  'plans.task_schedules.filter_field' | translate
                }}</span>
                <select
                  class="plan-task-schedule__filter-select"
                  [ngModel]="fieldCultivationFilterId"
                  (ngModelChange)="onFieldFilterChange($event)"
                  [disabled]="!fieldFilterOptions.length"
                >
                  <option [ngValue]="null">{{
                    'plans.task_schedules.filter_all_fields' | translate
                  }}</option>
                  @for (field of fieldFilterOptions; track field.value) {
                    <option [ngValue]="field.value">{{ field.label }}</option>
                  }
                </select>
              </label>
              <label class="plan-task-schedule__filter">
                <span class="plan-task-schedule__filter-label">{{
                  'plans.task_schedules.filter_from_date' | translate
                }}</span>
                <input
                  type="date"
                  class="plan-task-schedule__filter-select"
                  [ngModel]="fromDate"
                  (ngModelChange)="onFromDateChange($event)"
                />
              </label>
            </div>
            <app-task-schedule-month-list [monthGroups]="scheduleMonthGroups" />
          }
        }
      </section>
    </main>
  `,
  styleUrls: ['./plan-task-schedule.component.css']
})
export class PlanTaskScheduleComponent implements PlanTaskScheduleView, OnInit {
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);
  private readonly useCase = inject(LoadPlanTaskScheduleUseCase);
  private readonly regenerateUseCase = inject(RegenerateTaskScheduleUseCase);
  private readonly subscribeSyncUseCase = inject(SubscribeTaskScheduleSyncUseCase);
  private readonly presenter = inject(PlanTaskSchedulePresenter);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly translate = inject(TranslateService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  private syncChannel: Channel | null = null;

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get fieldCultivationFilterId(): number | null {
    return this.control.fieldCultivationFilterId;
  }

  get fromDate(): string {
    return this.control.fromDate;
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

  get cropIdsForBanner(): number[] {
    return this.control.cropIdsForBanner;
  }

  get cropNamesForBanner(): Record<number, string> {
    return this.control.cropNamesForBanner;
  }

  get scheduleMonthGroups() {
    return this.control.monthGroups;
  }

  get fieldFilterOptions() {
    return this.control.fieldFilterOptions;
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
    this.presenter.applyClientFilters(
      this.resolveFromDateFromRoute(),
      this.resolveFieldCultivationFilterFromRoute()
    );
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
      planId
    });
  }

  onFieldFilterChange(fieldCultivationId: number | null): void {
    if (this.fieldCultivationFilterId === fieldCultivationId) {
      return;
    }
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: {
        field_cultivation_id: fieldCultivationId
      },
      queryParamsHandling: 'merge',
      replaceUrl: true
    });
    this.presenter.applyClientFilters(this.fromDate, fieldCultivationId);
    this.cdr.markForCheck();
  }

  onFromDateChange(fromDate: string): void {
    if (!fromDate || this.fromDate === fromDate) {
      return;
    }
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: { from_date: fromDate },
      queryParamsHandling: 'merge',
      replaceUrl: true
    });
    this.presenter.applyClientFilters(fromDate, this.fieldCultivationFilterId);
    this.cdr.markForCheck();
  }

  private resolveFieldCultivationFilterFromRoute(): number | null {
    const raw = this.route.snapshot.queryParamMap.get('field_cultivation_id');
    if (!raw) {
      return null;
    }
    const parsed = Number(raw);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
  }

  private resolveFromDateFromRoute(): string {
    const raw = this.route.snapshot.queryParamMap.get('from_date');
    if (raw && ISO_DATE_PATTERN.test(raw)) {
      return raw;
    }
    return localTodayIso();
  }

  regenerateTaskSchedule(): void {
    this.regenerateUseCase.execute({ planId: this.planId });
  }
}
