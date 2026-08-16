import { Component, ElementRef, EventEmitter, Input, Output, ViewChild, inject } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDateForDisplay, formatIsoDayForDisplay, formatIsoMonthForDisplay } from '../../core/format-display-date';
import type { PlanTaskScheduleMonthGroupView, PlanTaskScheduleRowView } from './plan-task-schedule.view';
import type { PlanTaskScheduleItem } from '../../domain/work-schedule/plan-schedule-snapshot';
import { TaskScheduleItemDetailComponent } from './task-schedule-item-detail.component';
import {
  resolvePlanTaskScheduleVarianceBadge,
  type PlanTaskScheduleVarianceBadge
} from '../../domain/work-schedule/resolve-plan-task-schedule-variance-badge';
import {
  resolvePlanTaskScheduleAmountVarianceBadge,
  type PlanTaskScheduleAmountVarianceBadge
} from '../../domain/work-schedule/resolve-plan-task-schedule-amount-variance-badge';
import { formatPlanTaskScheduleAmountDeltaLabel } from '../../domain/work-schedule/format-plan-task-schedule-amount-delta';
import {
  formatPlanTaskScheduleAverageDeltaDaysLabel,
  formatPlanTaskScheduleDeltaDaysLabel
} from '../../domain/work-schedule/format-plan-task-schedule-delta-days';

@Component({
  selector: 'app-task-schedule-month-list',
  standalone: true,
  imports: [TranslateModule, TaskScheduleItemDetailComponent, RouterLink],
  template: `
    @if (!monthGroups.length && !unscheduledRows.length) {
      <p class="plan-task-schedule-month-list__empty">{{
        'plans.task_schedules.list_empty' | translate
      }}</p>
    } @else {
      <div>
        @if (unscheduledRows.length) {
          <section
            class="plan-task-schedule-month-list__month plan-task-schedule-month-list__month--unscheduled"
            [attr.aria-label]="'plans.task_schedules.unscheduled_title' | translate"
          >
            <h3 class="plan-task-schedule-month-list__month-title">{{
              'plans.task_schedules.unscheduled_title' | translate
            }}</h3>
            <ul class="plan-task-schedule-month-list__list" role="list">
              @for (row of unscheduledRows; track row.item.item_id) {
                <li>
                  <button
                    type="button"
                    class="plan-task-schedule-month-list__row"
                    [class.plan-task-schedule-month-list__row--selected]="isSelected(row)"
                    (click)="selectRow(row)"
                  >
                    <span class="plan-task-schedule-month-list__main">
                      <span class="plan-task-schedule-month-list__name">{{ row.item.name }}</span>
                      <span class="plan-task-schedule-month-list__sub">
                        <span class="plan-task-schedule-month-list__meta">{{
                          'plans.task_schedules.list_row_meta'
                            | translate: { field: row.fieldName, crop: row.cropName }
                        }}</span>
                      </span>
                    </span>
                    <span class="plan-task-schedule-month-list__badges">
                      <span [class]="statusModifierClass(row)">{{
                        statusLabelKey(row) | translate
                      }}</span>
                      @if (varianceBadge(row); as badge) {
                        @if (planId != null) {
                          <a
                            class="plan-task-schedule-month-list__variance plan-task-schedule-month-list__variance-link"
                            [class]="varianceModifierClass(badge)"
                            [attr.aria-label]="varianceAriaLabel(badge)"
                            [routerLink]="['/plans', planId, 'learn']"
                            fragment="plan-learn-current-variance-title"
                            (click)="$event.stopPropagation()"
                          >
                            {{ varianceDeltaLabel(badge) }}
                          </a>
                        } @else {
                          <span
                            class="plan-task-schedule-month-list__variance"
                            [class]="varianceModifierClass(badge)"
                            [attr.aria-label]="varianceAriaLabel(badge)"
                          >
                            {{ varianceDeltaLabel(badge) }}
                          </span>
                        }
                      }
                      @if (amountVarianceBadge(row); as amountBadge) {
                        <span
                          class="plan-task-schedule-month-list__amount-variance"
                          [class]="amountVarianceModifierClass(amountBadge)"
                          [attr.aria-label]="amountVarianceAriaLabel(amountBadge)"
                        >
                          {{ amountVarianceDeltaLabel(amountBadge) }}
                        </span>
                      }
                    </span>
                  </button>
                </li>
              }
            </ul>
          </section>
        }
        @for (group of monthGroups; track group.monthKey) {
          <section
            class="plan-task-schedule-month-list__month"
            [attr.aria-label]="formatMonth(group.monthKey)"
          >
            <h3 class="plan-task-schedule-month-list__month-title">
              <span>{{ formatMonth(group.monthKey) }}</span>
              @if (group.averageDeltaDays != null) {
                <span class="plan-task-schedule-month-list__month-average">
                  {{
                    'plans.task_schedules.variance.month_average'
                      | translate: { delta: formatAverageDelta(group.averageDeltaDays) }
                  }}
                </span>
              }
            </h3>
            <ul class="plan-task-schedule-month-list__list" role="list">
              @for (row of group.rows; track row.item.item_id) {
                <li>
                  <button
                    type="button"
                    class="plan-task-schedule-month-list__row"
                    [class.plan-task-schedule-month-list__row--selected]="isSelected(row)"
                    (click)="selectRow(row)"
                  >
                    <span class="plan-task-schedule-month-list__main">
                      <span class="plan-task-schedule-month-list__name">{{ row.item.name }}</span>
                      <span class="plan-task-schedule-month-list__sub">
                        <input
                          type="date"
                          class="plan-task-schedule-month-list__date-input"
                          [value]="row.item.scheduled_date ?? ''"
                          [attr.aria-label]="'plans.task_schedules.edit_scheduled_date' | translate"
                          (click)="$event.stopPropagation()"
                          (change)="emitScheduledDateChange(row, $event)"
                        />
                        <span class="plan-task-schedule-month-list__meta">{{
                          'plans.task_schedules.list_row_meta'
                            | translate: { field: row.fieldName, crop: row.cropName }
                        }}</span>
                      </span>
                    </span>
                    <span class="plan-task-schedule-month-list__badges">
                      <span [class]="statusModifierClass(row)">{{
                        statusLabelKey(row) | translate
                      }}</span>
                      @if (varianceBadge(row); as badge) {
                        @if (planId != null) {
                          <a
                            class="plan-task-schedule-month-list__variance plan-task-schedule-month-list__variance-link"
                            [class]="varianceModifierClass(badge)"
                            [attr.aria-label]="varianceAriaLabel(badge)"
                            [routerLink]="['/plans', planId, 'learn']"
                            fragment="plan-learn-current-variance-title"
                            (click)="$event.stopPropagation()"
                          >
                            {{ varianceDeltaLabel(badge) }}
                          </a>
                        } @else {
                          <span
                            class="plan-task-schedule-month-list__variance"
                            [class]="varianceModifierClass(badge)"
                            [attr.aria-label]="varianceAriaLabel(badge)"
                          >
                            {{ varianceDeltaLabel(badge) }}
                          </span>
                        }
                      }
                      @if (amountVarianceBadge(row); as amountBadge) {
                        <span
                          class="plan-task-schedule-month-list__amount-variance"
                          [class]="amountVarianceModifierClass(amountBadge)"
                          [attr.aria-label]="amountVarianceAriaLabel(amountBadge)"
                        >
                          {{ amountVarianceDeltaLabel(amountBadge) }}
                        </span>
                      }
                    </span>
                  </button>
                </li>
              }
            </ul>
          </section>
        }
      </div>
      <dialog
        #detailDialog
        class="form-dialog task-schedule-detail-dialog"
        [attr.aria-labelledby]="selectedRow ? 'task-schedule-detail-title' : null"
        (cancel)="closeDetail()"
        (close)="onDetailDialogClose()"
        (click)="onDetailDialogBackdropClick($event)"
      >
        @if (selectedRow) {
          <header class="task-schedule-detail-dialog__hero">
            @if (selectedRow.item.scheduled_date) {
              <time class="task-schedule-detail-dialog__date">{{
                formatScheduledDate(selectedRow.item.scheduled_date)
              }}</time>
            }
            <h3 id="task-schedule-detail-title" class="task-schedule-detail-dialog__title">
              {{
                'plans.task_schedules.detail.dialog_title'
                  | translate: { task: selectedRow.item.name, crop: selectedRow.cropName }
              }}
            </h3>
            <p class="task-schedule-detail-dialog__field">{{ selectedRow.fieldName }}</p>
          </header>
        }
        <div class="task-schedule-detail-dialog__body">
          <app-task-schedule-item-detail [task]="selectedTask" />
        </div>
        <div class="form-card__actions task-schedule-detail-dialog__actions">
          <button type="button" class="btn btn-secondary" (click)="closeDetail()">
            {{ 'common.close' | translate }}
          </button>
        </div>
      </dialog>
    }
  `,
  styleUrls: ['./task-schedule-month-list.component.css']
})
export class TaskScheduleMonthListComponent {
  private readonly translate = inject(TranslateService);

  @ViewChild('detailDialog') private detailDialogRef?: ElementRef<HTMLDialogElement>;

  @Input({ required: true }) monthGroups: PlanTaskScheduleMonthGroupView[] = [];

  @Input() unscheduledRows: PlanTaskScheduleRowView[] = [];

  @Input() planId: number | null = null;

  @Input() amountDeltaByItemId: Record<number, number> = {};

  @Output() scheduledDateChange = new EventEmitter<{ itemId: number; scheduledDate: string }>();

  selectedRow: PlanTaskScheduleRowView | null = null;

  get selectedTask(): PlanTaskScheduleItem | null {
    return this.selectedRow?.item ?? null;
  }

  formatDay(iso: string): string {
    return formatIsoDayForDisplay(iso, this.translate.currentLang);
  }

  formatScheduledDate(iso: string): string {
    return formatIsoDateForDisplay(iso, this.translate.currentLang);
  }

  formatMonth(monthKey: string): string {
    return formatIsoMonthForDisplay(monthKey, this.translate.currentLang);
  }

  statusLabelKey(row: PlanTaskScheduleRowView): string {
    return `plans.task_schedules.status.${row.displayStatus}`;
  }

  statusModifierClass(row: PlanTaskScheduleRowView): string {
    return `plan-task-schedule-month-list__status plan-task-schedule-month-list__status--${row.displayStatus}`;
  }

  varianceBadge(row: PlanTaskScheduleRowView): PlanTaskScheduleVarianceBadge | null {
    return resolvePlanTaskScheduleVarianceBadge(row.item);
  }

  amountVarianceBadge(row: PlanTaskScheduleRowView): PlanTaskScheduleAmountVarianceBadge | null {
    const amountDelta = this.amountDeltaByItemId[row.item.item_id] ?? null;
    return resolvePlanTaskScheduleAmountVarianceBadge({
      status: row.item.status,
      amountDelta
    });
  }

  amountVarianceModifierClass(badge: PlanTaskScheduleAmountVarianceBadge): string {
    return `plan-task-schedule-month-list__amount-variance--${badge.kind}`;
  }

  amountVarianceDeltaLabel(badge: PlanTaskScheduleAmountVarianceBadge): string {
    return formatPlanTaskScheduleAmountDeltaLabel(badge.amountDelta);
  }

  amountVarianceAriaLabel(badge: PlanTaskScheduleAmountVarianceBadge): string {
    return this.translate.instant(`plans.task_schedules.variance.amount_badge.${badge.kind}`, {
      delta: formatPlanTaskScheduleAmountDeltaLabel(badge.amountDelta)
    });
  }

  varianceModifierClass(badge: PlanTaskScheduleVarianceBadge): string {
    return `plan-task-schedule-month-list__variance--${badge.kind}`;
  }

  varianceDeltaLabel(badge: PlanTaskScheduleVarianceBadge): string {
    return formatPlanTaskScheduleDeltaDaysLabel(badge);
  }

  varianceAriaLabel(badge: PlanTaskScheduleVarianceBadge): string {
    return this.translate.instant(`plans.task_schedules.variance.badge.${badge.kind}`, {
      delta: badge.deltaDays ?? 0
    });
  }

  formatAverageDelta(average: number): string {
    return formatPlanTaskScheduleAverageDeltaDaysLabel(average);
  }

  selectRow(row: PlanTaskScheduleRowView): void {
    this.selectedRow = row;
    this.detailDialogRef?.nativeElement?.showModal();
  }

  closeDetail(): void {
    this.detailDialogRef?.nativeElement?.close();
  }

  onDetailDialogBackdropClick(event: MouseEvent): void {
    if (event.target === this.detailDialogRef?.nativeElement) {
      this.closeDetail();
    }
  }

  onDetailDialogClose(): void {
    this.selectedRow = null;
  }

  isSelected(row: PlanTaskScheduleRowView): boolean {
    return this.selectedRow?.item.item_id === row.item.item_id;
  }

  emitScheduledDateChange(row: PlanTaskScheduleRowView, event: Event): void {
    const value = (event.target as HTMLInputElement).value;
    if (!value || value === row.item.scheduled_date) {
      return;
    }
    this.scheduledDateChange.emit({ itemId: row.item.item_id, scheduledDate: value });
  }
}
