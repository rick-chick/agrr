import { Component, DestroyRef, ElementRef, OnInit, ViewChild, inject, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
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
import { formatIsoDateTimeForDisplay } from '../../core/format-display-date';
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
  fieldFilterId: null,
  fieldCultivationFilterId: null,
  monthGroups: [],
  unscheduledRows: [],
  fieldFilterOptions: [],
  cropIdsForBanner: [],
  cropNamesForBanner: {},
  filteredFieldCount: 0,
  filteredTaskCount: 0,
  regenerateRequiresConfirm: false
};

@Component({
  selector: 'app-plan-task-schedule',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    RouterLink,
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
                <a
                  class="plan-work__empty-cta-link plan-work__cta--constrained"
                  [routerLink]="['/plans', planId]"
                >{{ 'plans.task_schedules.empty_cta' | translate }}</a>
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
            <div class="plan-task-schedule__filters">
              <label class="plan-task-schedule__filter">
                <span class="plan-task-schedule__filter-label">{{
                  'plans.task_schedules.filter_field' | translate
                }}</span>
                <select
                  class="plan-task-schedule__filter-select"
                  [ngModel]="fieldFilterId"
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
            <app-task-schedule-month-list
              [monthGroups]="scheduleMonthGroups"
              [unscheduledRows]="scheduleUnscheduledRows"
            />
            <footer class="plan-task-schedule__footer">
              <p class="plan-task-schedule__generated-at">{{ timelineGeneratedAtLabel }}</p>
              <p class="plan-task-schedule__summary">{{
                'plans.task_schedules.summary'
                  | translate: { fields: control.filteredFieldCount, tasks: control.filteredTaskCount }
              }}</p>
              @if (syncState === 'ready') {
                <button
                  type="button"
                  class="plan-task-schedule__regenerate-link"
                  [disabled]="control.regenerating"
                  (click)="requestRegenerateTaskSchedule()"
                >
                  {{
                    (control.regenerating
                      ? 'common.loading'
                      : 'plans.task_schedules.sync_retry') | translate
                  }}
                </button>
                @if (control.regenerateError) {
                  <p class="plan-task-schedule__regenerate-error" role="alert">
                    {{ control.regenerateError | translate }}
                  </p>
                }
              }
            </footer>
          }
        }
      </section>
    </main>

    <dialog
      #regenerateConfirmDialog
      class="confirm-dialog plan-task-schedule__regenerate-confirm"
      (cancel)="cancelRegenerateConfirmDialog($event)"
      (click)="onRegenerateConfirmDialogBackdropClick($event)"
    >
      <p class="confirm-dialog__message">{{
        'plans.task_schedules.regenerate_confirm' | translate
      }}</p>
      <div class="confirm-dialog__actions">
        <button type="button" class="btn-secondary" (click)="cancelRegenerateConfirmDialog()">
          {{ 'common.cancel' | translate }}
        </button>
        <button type="button" class="btn-primary" (click)="confirmRegenerateTaskSchedule()">
          {{ 'plans.task_schedules.sync_retry' | translate }}
        </button>
      </div>
    </dialog>
  `,
  styleUrls: ['./plan-task-schedule.component.css']
})
export class PlanTaskScheduleComponent implements PlanTaskScheduleView, OnInit {
  @ViewChild('regenerateConfirmDialog') regenerateConfirmDialogRef?: ElementRef<HTMLDialogElement>;

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

  get fieldFilterId(): number | null {
    return this.control.fieldFilterId;
  }

  get timelineGeneratedAtLabel(): string {
    const plan = this.control.schedule?.plan;
    if (!plan) {
      return this.translate.instant('plans.task_schedules.timeline_generated_unknown');
    }
    const datetime =
      plan.timeline_generated_at_display ||
      (plan.timeline_generated_at
        ? formatIsoDateTimeForDisplay(plan.timeline_generated_at, this.translate.currentLang)
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

  get scheduleUnscheduledRows() {
    return this.control.unscheduledRows;
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
      this.resolveFieldFilterFromRoute(),
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

  onFieldFilterChange(fieldFilterId: number | null): void {
    if (this.fieldFilterId === fieldFilterId && this.fieldCultivationFilterId == null) {
      return;
    }
    void this.router.navigate([], {
      relativeTo: this.route,
      queryParams: {
        field_id: fieldFilterId,
        field_cultivation_id: null
      },
      queryParamsHandling: 'merge',
      replaceUrl: true
    });
    this.presenter.applyClientFilters(this.fromDate, fieldFilterId, null);
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
    this.presenter.applyClientFilters(fromDate, this.fieldFilterId, this.fieldCultivationFilterId);
    this.cdr.markForCheck();
  }

  private resolveFieldFilterFromRoute(): number | null {
    const raw = this.route.snapshot.queryParamMap.get('field_id');
    if (!raw) {
      return null;
    }
    const parsed = Number(raw);
    return Number.isFinite(parsed) && parsed > 0 ? parsed : null;
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
    this.requestRegenerateTaskSchedule();
  }

  requestRegenerateTaskSchedule(): void {
    if (this.control.regenerating) {
      return;
    }
    if (this.control.regenerateRequiresConfirm) {
      this.regenerateConfirmDialogRef?.nativeElement?.showModal();
      return;
    }
    this.executeRegenerateTaskSchedule();
  }

  confirmRegenerateTaskSchedule(): void {
    this.regenerateConfirmDialogRef?.nativeElement?.close();
    this.executeRegenerateTaskSchedule();
  }

  cancelRegenerateConfirmDialog(event?: Event): void {
    event?.preventDefault();
    this.regenerateConfirmDialogRef?.nativeElement?.close();
  }

  onRegenerateConfirmDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.regenerateConfirmDialogRef?.nativeElement) {
      this.cancelRegenerateConfirmDialog();
    }
  }

  private executeRegenerateTaskSchedule(): void {
    this.regenerateUseCase.execute({ planId: this.planId });
  }
}
