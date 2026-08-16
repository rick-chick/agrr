import { ChangeDetectorRef, Component, DestroyRef, ElementRef, HostListener, OnInit, ViewChild, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { Channel } from 'actioncable';
import { combineLatest } from 'rxjs';
import { formatIsoDateForDisplay } from '../../core/format-display-date';
import { localTodayIso } from '../../core/local-today';
import { PlanWorkPresenter } from '../../adapters/plans/plan-work.presenter';
import { LoadWorkDayListUseCase } from '../../usecase/plans/load-work-day-list.usecase';
import { PLAN_WORK_PROVIDERS } from '../../usecase/plans/plan-work.providers';
import { SkipTaskScheduleItemUseCase } from '../../usecase/plans/skip-task-schedule-item.usecase';
import { UpdateTaskScheduleItemUseCase } from '../../usecase/plans/update-task-schedule-item.usecase';
import { CreateWorkRecordUseCase } from '../../usecase/plans/create-work-record.usecase';
import { WorkDayListRowDto } from '../../usecase/plans/load-work-day-list.dtos';
import { resolveCropIdForFieldCultivation } from '../../domain/work-schedule/work-record-sheet-schedule';
import { PlanPlanContextHeaderComponent } from './plan-plan-context-header.component';
import { WorkRecordSheetSavedEvent } from './work-record-sheet.view';
import { PlanWorkView, PlanWorkViewState } from './plan-work.view';
import { WorkRecordSheetComponent } from './work-record-sheet.component';
import { TaskScheduleSyncBannerComponent } from './task-schedule-sync-banner.component';
import { RegenerateTaskScheduleUseCase } from '../../usecase/plans/regenerate-task-schedule.usecase';
import { SubscribeTaskScheduleSyncUseCase } from '../../usecase/plans/subscribe-task-schedule-sync.usecase';
import { emptyPlanSaveImpactViewFields } from '../../adapters/plans/plan-save-impact.presenter.helpers';
import { FlashMessageService } from '../../services/flash-message.service';
import { LoadPlanVsActualSummaryUseCase } from '../../usecase/plans/load-plan-vs-actual-summary.usecase';
import { applyPlanWorkViewEffects } from './plan-work-view.effects';
import { WorkRecordSaveImpactPanelComponent } from './work-record-save-impact-panel.component';
import { PlanWorkVarianceSummaryComponent } from './plan-work-variance-summary.component';
import { PlanWorkTodayAttentionComponent } from './plan-work-today-attention.component';
import { PlanWorkMiniClimatePanelComponent } from './plan-work-mini-climate-panel.component';
import { findVarianceActionItemForTask } from '../../domain/plans/find-variance-action-item-for-task';
import { buildPlanWorkTodayAttention } from '../../domain/plans/build-plan-work-today-attention';
import type { PlanWorkTodayAttentionSummary } from '../../domain/plans/build-plan-work-today-attention';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';
import { formatVarianceDeltaDays, formatVarianceGddDelta } from '../../domain/plans/work-record-variance';
import {
  resolveWorkRowGddGapState,
  resolveWorkRowGddTrigger,
  resolveWorkRowWeatherDependency,
  shouldShowWorkRowGddGapBadge,
  type WorkRowGddGapState
} from '../../domain/work-schedule/work-row-context-badges';
import {
  filterWorkDayListBySegment,
  formatWorkRowAmountDiffLabel,
  isFertilizerWorkRow,
  isPestControlWorkRow,
  resolveFertilizerTaskKind,
  resolvePestControlTaskKind,
  resolveWorkRowAmountDiff,
  type FertilizerTaskKind,
  type PestControlTaskKind,
  type WorkListSegment
} from '../../domain/work-schedule/work-row-fertilizer';
import { isHarvestWorkRow } from '../../domain/work-schedule/work-row-harvest';
import type { WorkRecordAmountDiff } from '../../domain/work-schedule/work-record-amount-diff';

const initialControl: PlanWorkViewState = {
  loading: true,
  error: null,
  plan: null,
  fields: [],
  overdue: [],
  today: [],
  upcoming: [],
  includeSkipped: false,
  workSegment: 'all',
  recentAdHocRecord: null,
  nextScheduled: null,
  highlightedItemId: null,
  completingItemId: null,
  regenerating: false,
  regenerateError: null,
  pendingSyncToastKey: null,
  pendingRecordSavedToast: null,
  pendingRecordSavedEvent: null,
  ...emptyPlanSaveImpactViewFields,
  pendingQuickCompleteValidation: null,
  syncReloadNonce: 0,
  cropIdsForBanner: [],
  cropNamesForBanner: {},
  varianceSummaryLoading: true,
  varianceSummaryError: null,
  varianceSummaryStats: null,
  actionRequiredItems: []
};

@Component({
  selector: 'app-plan-work',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    RouterLink,
    TranslateModule,
    PlanPlanContextHeaderComponent,
    WorkRecordSheetComponent,
    TaskScheduleSyncBannerComponent,
    WorkRecordSaveImpactPanelComponent,
    PlanWorkVarianceSummaryComponent,
    PlanWorkTodayAttentionComponent,
    PlanWorkMiniClimatePanelComponent
  ],
  providers: [...PLAN_WORK_PROVIDERS],
  template: `
    <div class="page-main page-main--fit">
      <app-plan-plan-context-header
        [planId]="planId"
        [planName]="control.plan?.name ?? null"
        pageTitleKey="plans.work.page_title"
      />

      <section class="section-card plan-work" aria-labelledby="plan-context-page-title">
        @if (control.loading) {
          <p class="master-loading">{{ 'common.loading' | translate }}</p>
        } @else if (control.error) {
          <div class="page-alert-error plan-work__error" role="alert">
            <p>{{ control.error | translate }}</p>
            <button type="button" class="btn-secondary plan-work__retry" (click)="reload()">
              {{ 'plans.work.retry' | translate }}
            </button>
          </div>
        } @else if (control.plan) {
          <app-task-schedule-sync-banner
            [syncState]="control.plan.task_schedule_sync_state"
            [syncError]="control.plan.task_schedule_sync_error"
            [syncErrorCropId]="control.plan.task_schedule_sync_error_crop_id"
            [cropIds]="cropIdsForBanner"
            [cropNames]="cropNamesForBanner"
            [planId]="planId"
            returnTab="work"
            [regenerating]="control.regenerating"
            [regenerateError]="control.regenerateError"
            (retry)="regenerateTaskSchedule()"
          />

          <app-plan-work-variance-summary
            [planId]="planId"
            [stats]="control.varianceSummaryStats"
            [loading]="control.varianceSummaryLoading"
            [error]="control.varianceSummaryError"
          />

          <app-plan-work-today-attention
            [planId]="planId"
            [summary]="todayAttentionSummary"
            [loading]="todayAttentionLoading"
            [error]="control.varianceSummaryError"
          />

          <div
            class="plan-work__segment"
            role="group"
            [attr.aria-label]="'plans.work.segment.label' | translate"
          >
            <button
              type="button"
              class="plan-work__segment-btn"
              [class.plan-work__segment-btn--active]="control.workSegment === 'all'"
              (click)="setWorkSegment('all')"
            >
              {{ 'plans.work.segment.all' | translate }}
            </button>
            <button
              type="button"
              class="plan-work__segment-btn"
              [class.plan-work__segment-btn--active]="control.workSegment === 'fertilizer'"
              (click)="setWorkSegment('fertilizer')"
            >
              {{ 'plans.work.segment.fertilizer' | translate }}
            </button>
            <button
              type="button"
              class="plan-work__segment-btn"
              [class.plan-work__segment-btn--active]="control.workSegment === 'pest_control'"
              (click)="setWorkSegment('pest_control')"
            >
              {{ 'plans.work.segment.pest_control' | translate }}
            </button>
          </div>

          @if (control.saveImpactLoading || control.saveImpact || control.saveImpactError) {
            <app-work-record-save-impact-panel
              [planId]="planId"
              [impact]="control.saveImpact"
              [loading]="control.saveImpactLoading"
              [error]="control.saveImpactError"
              (dismiss)="dismissSaveImpact()"
            />
          }

          @if (filteredOverdue.length) {
            <section class="plan-work__section">
              <h3 class="plan-work__section-title plan-work__section-title--overdue">
                {{ 'plans.work.section.overdue' | translate: { count: filteredOverdue.length } }}
              </h3>
              <ul class="plan-work__list">
                @for (row of filteredOverdue; track row.item.item_id) {
                  <ng-container
                    *ngTemplateOutlet="rowTpl; context: { $implicit: row, overdue: true }"
                  />
                }
              </ul>
            </section>
          }

          <section class="plan-work__section">
            <div class="plan-work__section-header">
              <h3 class="plan-work__section-title plan-work__section-title--today">{{
                'plans.work.section.today' | translate: { date: todayLabel }
              }}</h3>
              <label class="plan-work__toggle">
                <input
                  type="checkbox"
                  [checked]="control.includeSkipped"
                  (change)="toggleSkipped($event)"
                />
                {{ 'plans.work.show_skipped' | translate }}
              </label>
            </div>
            @if (filteredToday.length) {
              <ul class="plan-work__list">
                @for (row of filteredToday; track row.item.item_id) {
                  <ng-container *ngTemplateOutlet="rowTpl; context: { $implicit: row }" />
                }
              </ul>
            } @else if (control.recentAdHocRecord) {
              <div class="plan-work__recent-adhoc" role="status" aria-live="polite">
                <p class="plan-work__recent-adhoc-message">{{
                  'plans.work.recent_adhoc'
                    | translate
                      : {
                          name: control.recentAdHocRecord.name,
                          date: displayDate(control.recentAdHocRecord.actualDate)
                        }
                }}</p>
                <a
                  class="plan-work__recent-adhoc-link"
                  [routerLink]="['/plans', planId, 'work_records']"
                >{{ 'plans.work.recent_adhoc_history_link' | translate }}</a>
                <button
                  type="button"
                  class="btn-primary plan-work__empty-cta plan-work__cta--constrained"
                  (click)="openAdHoc()"
                >
                  {{ 'plans.work.add_record' | translate }}
                </button>
              </div>
            } @else {
              <div class="plan-work__empty">
                <p class="plan-work__empty-message">{{ 'plans.work.empty_today' | translate }}</p>
                @if (control.nextScheduled) {
                  <p class="plan-work__empty-hint">{{
                    'plans.work.next_scheduled'
                      | translate
                        : {
                            name: control.nextScheduled.item.name,
                            date: displayDate(control.nextScheduled.item.scheduled_date!),
                            field: control.nextScheduled.fieldName
                          }
                  }}</p>
                  <a
                    class="plan-work__empty-cta-link plan-work__cta--constrained"
                    [routerLink]="['/plans', planId, 'task_schedule']"
                  >{{ 'plans.work.empty_task_schedule_cta' | translate }}</a>
                } @else {
                  <p class="plan-work__empty-hint">{{ 'plans.work.empty_today_hint' | translate }}</p>
                  <a
                    class="plan-work__empty-cta-link plan-work__cta--constrained"
                    [routerLink]="['/plans', planId]"
                  >{{ 'plans.work.empty_plan_cta' | translate }}</a>
                  <a
                    class="plan-work__empty-cta-link plan-work__cta--constrained"
                    [routerLink]="['/plans', planId, 'task_schedule']"
                  >{{ 'plans.work.empty_task_schedule_cta' | translate }}</a>
                }
                <button
                  type="button"
                  class="btn-primary plan-work__empty-cta plan-work__cta--constrained"
                  (click)="openAdHoc()"
                >
                  {{ 'plans.work.add_record' | translate }}
                </button>
              </div>
            }
          </section>

          @if (filteredUpcoming.length) {
            <section class="plan-work__section">
              <h3 class="plan-work__section-title">{{ 'plans.work.section.upcoming' | translate }}</h3>
              <ul class="plan-work__list">
                @for (row of filteredUpcoming; track row.item.item_id) {
                  <ng-container *ngTemplateOutlet="rowTpl; context: { $implicit: row }" />
                }
              </ul>
            </section>
          }

          @if (filteredToday.length) {
            <footer class="plan-work__fab">
              <button
                type="button"
                class="btn-primary plan-work__fab-btn plan-work__cta--constrained"
                (click)="openAdHoc()"
              >
                {{ 'plans.work.add_record' | translate }}
              </button>
            </footer>
          }
        }
      </section>
    </div>

    <ng-template #rowTpl let-row let-overdue="overdue">
      <li
        class="plan-work__row"
        [class.plan-work__row--done]="row.recordedToday"
        [class.plan-work__row--overdue]="overdue"
        [class.plan-work__row--highlight]="control.highlightedItemId === row.item.item_id"
        [class.plan-work__row--expanded]="expandedRowItemId === row.item.item_id"
      >
        <div class="plan-work__row-body">
          <div class="plan-work__row-main">
            @if (row.item.field_cultivation_id != null) {
              <button
                type="button"
                class="plan-work__row-expand-btn"
                data-testid="work-row-expand-toggle"
                [attr.aria-expanded]="expandedRowItemId === row.item.item_id"
                [attr.aria-label]="
                  (expandedRowItemId === row.item.item_id
                    ? 'plans.work.mini_climate.collapse'
                    : 'plans.work.mini_climate.expand') | translate
                "
                (click)="toggleRowExpand(row.item.item_id)"
              >
                <span aria-hidden="true">
                  {{ expandedRowItemId === row.item.item_id ? '▼' : '▶' }}
                </span>
              </button>
            }
          <span class="plan-work__date">{{ displayDate(row.item.scheduled_date) }}</span>
          @if (overdue && row.overdueDays != null) {
            <span class="plan-work__overdue-days">
              {{ 'plans.work.overdue_days' | translate: { count: row.overdueDays } }}
            </span>
          }
          <span class="plan-work__name">{{ row.item.name }}</span>
          <span class="plan-work__field">{{ row.fieldName }} {{ row.cropName }}</span>
          @if (row.recordedToday) {
            <span class="plan-work__done-badge">✓ {{ 'plans.work.recorded_today' | translate }}</span>
          }
          @if (row.item.status === 'skipped') {
            <span class="plan-work__skip-badge">{{ 'plans.work.skipped_badge' | translate }}</span>
          }
          @if (fertilizerKindForRow(row); as fertilizerKind) {
            <span
              class="plan-work__fertilizer-badge"
              [class.plan-work__fertilizer-badge--basal]="fertilizerKind === 'basal'"
              [class.plan-work__fertilizer-badge--topdress]="fertilizerKind === 'topdress'"
            >
              {{
                (fertilizerKind === 'basal'
                  ? 'plans.work.fertilizer_badge.basal'
                  : 'plans.work.fertilizer_badge.topdress') | translate
              }}
            </span>
          }
          @if (pestControlKindForRow(row); as pestControlKind) {
            <span
              class="plan-work__pest-control-badge"
              [class.plan-work__pest-control-badge--preventive]="pestControlKind === 'preventive'"
              [class.plan-work__pest-control-badge--curative]="pestControlKind === 'curative'"
            >
              {{
                (pestControlKind === 'preventive'
                  ? 'plans.work.pest_control_badge.preventive'
                  : 'plans.work.pest_control_badge.curative') | translate
              }}
            </span>
          }
          @if (isHarvestRow(row)) {
            <span class="plan-work__harvest-badge">
              {{ 'plans.work.harvest_badge.label' | translate }}
            </span>
          }
          @if (amountDiffForRow(row); as amountDiff) {
            @if (amountDiffLabelForRow(amountDiff)) {
              <span
                class="plan-work__amount-diff"
                [class.plan-work__amount-diff--over]="amountDiff.diff != null && amountDiff.diff > 0"
                [class.plan-work__amount-diff--under]="amountDiff.diff != null && amountDiff.diff < 0"
              >
                {{ amountDiffLabelForRow(amountDiff) }}
              </span>
            }
          }
          @if (varianceActionItemForRow(row); as actionItem) {
            @if (showDaysExceedanceBadge(actionItem)) {
              <span class="plan-work__exceedance-badge plan-work__exceedance-badge--days">
                {{
                  'plans.work.exceedance_badge.days'
                    | translate: { delta: daysExceedanceLabel(actionItem) }
                }}
              </span>
            }
            @if (showGddExceedanceBadge(actionItem)) {
              <span class="plan-work__exceedance-badge plan-work__exceedance-badge--gdd">
                {{
                  'plans.work.exceedance_badge.gdd'
                    | translate: { delta: gddExceedanceLabel(actionItem) }
                }}
              </span>
            }
          }
          @if (gddTriggerForRow(row); as gddTrigger) {
            <span class="plan-work__context-badge plan-work__context-badge--gdd-trigger">
              {{
                'plans.work.context_badge.gdd_trigger'
                  | translate: { value: formatGddTriggerLabel(gddTrigger) }
              }}
            </span>
          }
          @if (showGddGapBadgeForRow(row)) {
            @if (gddGapStateForRow(row); as gapState) {
              @if (gapState.kind === 'reached') {
                <span class="plan-work__context-badge plan-work__context-badge--gdd-reached">
                  {{ 'plans.work.context_badge.gdd_reached' | translate }}
                </span>
              } @else if (gapState.kind === 'shortfall') {
                <span class="plan-work__context-badge plan-work__context-badge--gdd-gap">
                  {{
                    'plans.work.context_badge.gdd_shortfall'
                      | translate: { gap: formatGddGapLabel(gapState.gap) }
                  }}
                </span>
              }
            }
          }
          @if (weatherDependencyForRow(row); as weatherDependency) {
            <span class="plan-work__context-badge plan-work__context-badge--weather">
              {{
                ('plans.work.context_badge.weather_' + weatherDependency) | translate
              }}
            </span>
          }
        </div>
          @if (
            expandedRowItemId === row.item.item_id && row.item.field_cultivation_id != null
          ) {
            <app-plan-work-mini-climate-panel
              [planId]="planId"
              [fieldCultivationId]="row.item.field_cultivation_id"
            />
          }
        </div>
        <div class="plan-work__row-actions">
          @if (!row.recordedToday && row.item.status !== 'skipped') {
            <button
              type="button"
              class="btn-primary plan-work__complete-btn"
              [disabled]="control.completingItemId === row.item.item_id"
              (click)="quickComplete(row)"
            >
              @if (control.completingItemId === row.item.item_id) {
                {{ 'common.loading' | translate }}
              } @else {
                {{ 'plans.work.complete' | translate }}
              }
            </button>
          }
          <button
            type="button"
            class="plan-work__menu-btn"
            [attr.aria-label]="'plans.work.menu' | translate"
            [attr.aria-expanded]="openMenuItemId === row.item.item_id"
            (click)="toggleMenu(row.item.item_id, $event)"
          >⋮</button>
          @if (openMenuItemId === row.item.item_id) {
            <div class="plan-work__menu" role="menu">
              @if (row.item.status === 'skipped') {
                <button type="button" role="menuitem" (click)="unskip(row)">
                  {{ 'plans.work.unskip' | translate }}
                </button>
              } @else {
                <button type="button" role="menuitem" (click)="openChangeDate(row)">
                  {{ 'plans.work.change_date' | translate }}
                </button>
                <button type="button" role="menuitem" (click)="openCompleteWithDetails(row)">
                  {{ 'plans.work.record_with_details' | translate }}
                </button>
                <button type="button" role="menuitem" (click)="skip(row)">
                  {{ 'plans.work.skip' | translate }}
                </button>
              }
            </div>
          }
        </div>
      </li>
    </ng-template>

    <app-work-record-sheet
      [planId]="planId"
      (saved)="onRecordSaved($event)"
      (deleted)="reload({ silent: true })"
    />

    <dialog
      #changeDateDialog
      class="form-dialog plan-work__change-date-dialog"
      (cancel)="closeChangeDateDialog($event)"
      (click)="onChangeDateDialogBackdropClick($event)"
    >
      @if (changeDateRow) {
        <h3 class="plan-work__change-date-title">{{ 'plans.work.change_date' | translate }}</h3>
        <p class="plan-work__change-date-task">{{ changeDateRow.item.name }}</p>
        <label class="plan-work__change-date-label">
          <span>{{ 'plans.work.change_date_field' | translate }}</span>
          <input
            type="date"
            class="plan-work__change-date-input"
            [(ngModel)]="changeDateValue"
          />
        </label>
        <div class="confirm-dialog__actions">
          <button type="button" class="btn-secondary" (click)="closeChangeDateDialog()">
            {{ 'common.cancel' | translate }}
          </button>
          <button type="button" class="btn-primary" (click)="submitChangeDate()">
            {{ 'plans.work.change_date_submit' | translate }}
          </button>
        </div>
      }
    </dialog>
  `,
  styleUrls: ['./plan-work.component.css']
})
export class PlanWorkComponent implements PlanWorkView, OnInit {
  @ViewChild(WorkRecordSheetComponent) sheet!: WorkRecordSheetComponent;
  @ViewChild('changeDateDialog') changeDateDialogRef?: ElementRef<HTMLDialogElement>;

  private readonly route = inject(ActivatedRoute);
  private readonly loadUseCase = inject(LoadWorkDayListUseCase);
  private readonly skipUseCase = inject(SkipTaskScheduleItemUseCase);
  private readonly updateItemUseCase = inject(UpdateTaskScheduleItemUseCase);
  private readonly createUseCase = inject(CreateWorkRecordUseCase);
  private readonly regenerateUseCase = inject(RegenerateTaskScheduleUseCase);
  private readonly subscribeSyncUseCase = inject(SubscribeTaskScheduleSyncUseCase);
  private readonly loadSummaryUseCase = inject(LoadPlanVsActualSummaryUseCase);
  private readonly presenter = inject(PlanWorkPresenter);
  private readonly translate = inject(TranslateService);
  private readonly flashMessage = inject(FlashMessageService);
  private readonly cdr = inject(ChangeDetectorRef);
  private readonly destroyRef = inject(DestroyRef);

  openMenuItemId: number | null = null;
  expandedRowItemId: number | null = null;
  changeDateRow: WorkDayListRowDto | null = null;
  changeDateValue = localTodayIso();
  private syncChannel: Channel | null = null;
  private highlightClearTimer: ReturnType<typeof setTimeout> | null = null;
  private pendingHighlightItemId: number | null = null;

  get planId(): number {
    return Number(this.route.snapshot.paramMap.get('id')) ?? 0;
  }

  get cropIdsForBanner(): number[] {
    return this.control.cropIdsForBanner;
  }

  get cropNamesForBanner(): Record<number, string> {
    return this.control.cropNamesForBanner;
  }

  get todayLabel(): string {
    return this.displayDate(localTodayIso());
  }

  get todayAttentionLoading(): boolean {
    return this.control.varianceSummaryLoading;
  }

  get todayAttentionSummary(): PlanWorkTodayAttentionSummary | null {
    if (this.todayAttentionLoading || this.control.varianceSummaryError) {
      return null;
    }
    return buildPlanWorkTodayAttention(
      {
        plan_id: this.planId,
        unrecorded_count: this.control.varianceSummaryStats?.unrecordedCount ?? 0,
        categories: [],
        top_variance_items: [],
        action_required_items: this.control.actionRequiredItems
      },
      [...this.control.overdue, ...this.control.today]
    );
  }

  get filteredOverdue(): WorkDayListRowDto[] {
    return filterWorkDayListBySegment(this.control.overdue, this.control.workSegment);
  }

  get filteredToday(): WorkDayListRowDto[] {
    return filterWorkDayListBySegment(this.control.today, this.control.workSegment);
  }

  get filteredUpcoming(): WorkDayListRowDto[] {
    return filterWorkDayListBySegment(this.control.upcoming, this.control.workSegment);
  }

  setWorkSegment(segment: WorkListSegment): void {
    this.control = { ...this.control, workSegment: segment };
  }

  fertilizerKindForRow(row: WorkDayListRowDto): FertilizerTaskKind | null {
    if (!isFertilizerWorkRow(row)) {
      return null;
    }
    return resolveFertilizerTaskKind(row.item);
  }

  pestControlKindForRow(row: WorkDayListRowDto): PestControlTaskKind | null {
    if (!isPestControlWorkRow(row)) {
      return null;
    }
    return resolvePestControlTaskKind(row.item);
  }

  isHarvestRow(row: WorkDayListRowDto): boolean {
    return isHarvestWorkRow(row);
  }

  amountDiffForRow(row: WorkDayListRowDto): WorkRecordAmountDiff | null {
    return resolveWorkRowAmountDiff(row);
  }

  amountDiffLabelForRow(diff: WorkRecordAmountDiff): string {
    return formatWorkRowAmountDiffLabel(diff);
  }

  displayDate(iso: string): string {
    return formatIsoDateForDisplay(iso, this.translate.currentLang);
  }

  varianceActionItemForRow(row: WorkDayListRowDto): PlanVarianceActionItem | null {
    return findVarianceActionItemForTask(
      row.item.item_id,
      this.control.actionRequiredItems
    );
  }

  showDaysExceedanceBadge(item: PlanVarianceActionItem): boolean {
    return item.exceedance_kind === 'days' || item.exceedance_kind === 'both';
  }

  showGddExceedanceBadge(item: PlanVarianceActionItem): boolean {
    return item.exceedance_kind === 'gdd' || item.exceedance_kind === 'both';
  }

  daysExceedanceLabel(item: PlanVarianceActionItem): string {
    return item.delta_days != null ? formatVarianceDeltaDays(item.delta_days) : '—';
  }

  gddExceedanceLabel(item: PlanVarianceActionItem): string {
    return item.gdd_delta != null ? formatVarianceGddDelta(item.gdd_delta) : '—';
  }

  gddTriggerForRow(row: WorkDayListRowDto): number | null {
    return resolveWorkRowGddTrigger(row.item);
  }

  formatGddTriggerLabel(trigger: number): string {
    return Number.isInteger(trigger) ? String(trigger) : trigger.toFixed(1);
  }

  gddGapStateForRow(row: WorkDayListRowDto): WorkRowGddGapState {
    return resolveWorkRowGddGapState(
      resolveWorkRowGddTrigger(row.item),
      row.cumulativeGddAtToday
    );
  }

  showGddGapBadgeForRow(row: WorkDayListRowDto): boolean {
    const actionItem = this.varianceActionItemForRow(row);
    const hasGddExceedance =
      actionItem != null && this.showGddExceedanceBadge(actionItem);
    return shouldShowWorkRowGddGapBadge(this.gddGapStateForRow(row), hasGddExceedance);
  }

  formatGddGapLabel(gap: number): string {
    return Number.isInteger(gap) ? String(gap) : gap.toFixed(1);
  }

  weatherDependencyForRow(row: WorkDayListRowDto): string | null {
    return resolveWorkRowWeatherDependency(row.item);
  }

  private _control: PlanWorkViewState = initialControl;
  get control(): PlanWorkViewState {
    return this._control;
  }
  set control(value: PlanWorkViewState) {
    const prevLoading = this._control.loading;
    this._control = applyPlanWorkViewEffects(this._control, value, {
      flash: this.flashMessage,
      onReload: () => this.reload({ silent: true }),
      scheduleHighlightClear: (itemId) => this.scheduleHighlightClear(itemId),
      onQuickCompleteValidation: (itemId, fieldErrors) => {
        const row = this.findRowByItemId(itemId);
        if (row) {
          const cropId = resolveCropIdForFieldCultivation(
            this.control.fields,
            row.item.field_cultivation_id
          );
          this.sheet.openFromItem(row, { fieldErrors, cropId });
        }
      },
      onLoadSaveImpact: (event) => this.loadSaveImpact(event)
    });
    if (prevLoading && !this._control.loading && !this._control.error) {
      this.applyPendingHighlightItem();
    }
    this.cdr.markForCheck();
  }

  ngOnInit(): void {
    this.presenter.setView(this);
    this.destroyRef.onDestroy(() => {
      this.syncChannel?.unsubscribe();
      if (this.highlightClearTimer !== null) {
        clearTimeout(this.highlightClearTimer);
      }
    });
    combineLatest([this.route.paramMap, this.route.queryParamMap])
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe(() => this.handleRouteChange());
  }

  private handleRouteChange(): void {
    if (!this.planId) {
      this.control = { ...initialControl, loading: false, error: 'plans.errors.invalid_id' };
      return;
    }
    this.pendingHighlightItemId = this.readHighlightItemIdFromRoute();
    this.syncChannel?.unsubscribe();
    this.syncChannel = null;
    this.subscribeSyncUseCase.execute({
      planId: this.planId,
      onSubscribed: (channel) => {
        this.syncChannel = channel;
      }
    });
    this.reload();
  }

  reload(options?: { silent?: boolean }): void {
    this.openMenuItemId = null;
    if (!options?.silent) {
      this.control = {
        ...this.control,
        loading: true,
        error: null,
        regenerateError: null
      };
    }
    const loadGeneration = this.presenter.beginScheduleLoad();
    const varianceLoadGeneration = this.presenter.beginPageVarianceLoad();
    this.loadUseCase.execute({
      planId: this.planId,
      today: localTodayIso(),
      includeSkipped: this.control.includeSkipped,
      loadGeneration
    });
    this.control = {
      ...this.control,
      varianceSummaryLoading: true,
      varianceSummaryError: null
    };
    this.loadSummaryUseCase.execute({ planId: this.planId, loadGeneration: varianceLoadGeneration });
  }

  regenerateTaskSchedule(): void {
    this.regenerateUseCase.execute({ planId: this.planId });
  }

  onRecordSaved(event: WorkRecordSheetSavedEvent): void {
    this.control = { ...this.control, pendingRecordSavedEvent: event };
  }

  dismissSaveImpact(): void {
    this.presenter.dismissSaveImpact();
  }

  private loadSaveImpact(event: WorkRecordSheetSavedEvent): void {
    const loadGeneration = this.presenter.queueSaveImpactAfterSave(event);
    if (loadGeneration > 0) {
      this.loadSummaryUseCase.execute({ planId: this.planId, loadGeneration });
    }
  }

  private scheduleHighlightClear(itemId: number): void {
    if (this.highlightClearTimer !== null) {
      clearTimeout(this.highlightClearTimer);
    }
    this.highlightClearTimer = setTimeout(() => {
      if (this.control.highlightedItemId === itemId) {
        this.control = { ...this.control, highlightedItemId: null };
      }
      this.highlightClearTimer = null;
    }, 3000);
  }

  private readHighlightItemIdFromRoute(): number | null {
    const raw = this.route.snapshot.queryParamMap.get('highlight_item');
    if (raw == null || raw === '') {
      return null;
    }
    const itemId = Number(raw);
    return Number.isFinite(itemId) ? itemId : null;
  }

  private applyPendingHighlightItem(): void {
    const itemId = this.pendingHighlightItemId;
    if (itemId == null) {
      return;
    }
    this.pendingHighlightItemId = null;
    if (!this.findRowByItemId(itemId)) {
      return;
    }
    this.control = { ...this.control, highlightedItemId: itemId };
    this.scheduleHighlightClear(itemId);
  }

  toggleSkipped(event: Event): void {
    const checked = (event.target as HTMLInputElement).checked;
    this.control = { ...this.control, includeSkipped: checked };
    this.reload();
  }

  quickComplete(row: WorkDayListRowDto): void {
    this.openMenuItemId = null;
    this.control = { ...this.control, completingItemId: row.item.item_id, error: null };
    this.createUseCase.execute({
      planId: this.planId,
      body: {
        task_schedule_item_id: row.item.item_id,
        actual_date: localTodayIso()
      }
    });
  }

  openCompleteWithDetails(row: WorkDayListRowDto): void {
    this.openMenuItemId = null;
    const cropId = resolveCropIdForFieldCultivation(
      this.control.fields,
      row.item.field_cultivation_id
    );
    this.sheet.openFromItem(row, { cropId });
  }

  private findRowByItemId(itemId: number): WorkDayListRowDto | null {
    const rows = [...this.control.overdue, ...this.control.today, ...this.control.upcoming];
    return rows.find((row) => row.item.item_id === itemId) ?? null;
  }

  openAdHoc(): void {
    this.sheet.openAdHoc(this.control.fields);
  }

  toggleMenu(itemId: number, event?: Event): void {
    event?.stopPropagation();
    this.openMenuItemId = this.openMenuItemId === itemId ? null : itemId;
  }

  toggleRowExpand(itemId: number): void {
    this.expandedRowItemId = this.expandedRowItemId === itemId ? null : itemId;
  }

  @HostListener('document:click', ['$event'])
  closeMenuOnOutsideClick(event: MouseEvent): void {
    if (this.openMenuItemId === null) return;
    const target = event.target as HTMLElement;
    if (target.closest('.plan-work__menu') || target.closest('.plan-work__menu-btn')) return;
    this.openMenuItemId = null;
  }

  skip(row: WorkDayListRowDto): void {
    this.openMenuItemId = null;
    this.skipUseCase.execute({ planId: this.planId, itemId: row.item.item_id, skip: true });
  }

  unskip(row: WorkDayListRowDto): void {
    this.openMenuItemId = null;
    this.skipUseCase.execute({ planId: this.planId, itemId: row.item.item_id, skip: false });
  }

  openChangeDate(row: WorkDayListRowDto): void {
    this.openMenuItemId = null;
    this.changeDateRow = row;
    this.changeDateValue = row.item.scheduled_date ?? localTodayIso();
    this.changeDateDialogRef?.nativeElement?.showModal();
  }

  closeChangeDateDialog(event?: Event): void {
    event?.preventDefault();
    this.changeDateDialogRef?.nativeElement?.close();
    this.changeDateRow = null;
  }

  onChangeDateDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.changeDateDialogRef?.nativeElement) {
      this.closeChangeDateDialog();
    }
  }

  submitChangeDate(): void {
    if (!this.changeDateRow || !this.changeDateValue) {
      return;
    }
    const row = this.changeDateRow;
    this.updateItemUseCase.execute({
      planId: this.planId,
      itemId: row.item.item_id,
      scheduledDate: this.changeDateValue,
      onSuccess: () => this.closeChangeDateDialog()
    });
  }
}
