import { Component, ElementRef, Input, ViewChild, inject } from '@angular/core';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDateForDisplay, formatIsoDayForDisplay, formatIsoMonthForDisplay } from '../../core/format-display-date';
import type { PlanTaskScheduleMonthGroupView, PlanTaskScheduleRowView } from './plan-task-schedule.view';
import type { PlanTaskScheduleItem } from '../../domain/work-schedule/plan-schedule-snapshot';
import { TaskScheduleItemDetailComponent } from './task-schedule-item-detail.component';

@Component({
  selector: 'app-task-schedule-month-list',
  standalone: true,
  imports: [TranslateModule, TaskScheduleItemDetailComponent],
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
                    <span [class]="statusModifierClass(row)">{{
                      statusLabelKey(row) | translate
                    }}</span>
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
            <h3 class="plan-task-schedule-month-list__month-title">{{ formatMonth(group.monthKey) }}</h3>
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
                        <time
                          class="plan-task-schedule-month-list__date"
                          [attr.datetime]="row.item.scheduled_date"
                          >{{ formatDay(row.item.scheduled_date!) }}</time
                        >
                        <span class="plan-task-schedule-month-list__meta">{{
                          'plans.task_schedules.list_row_meta'
                            | translate: { field: row.fieldName, crop: row.cropName }
                        }}</span>
                      </span>
                    </span>
                    <span [class]="statusModifierClass(row)">{{
                      statusLabelKey(row) | translate
                    }}</span>
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
}
