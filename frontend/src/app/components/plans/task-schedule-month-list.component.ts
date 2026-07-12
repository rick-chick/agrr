import { Component, Input, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDayForDisplay, formatIsoMonthForDisplay } from '../../core/format-display-date';
import type { PlanTaskScheduleMonthGroupView } from './plan-task-schedule.view';
import type { CrossFarmScheduleRow } from '../../domain/work-schedule/cross-farm-schedule-row';
import type { PlanTaskScheduleItem } from '../../domain/work-schedule/plan-schedule-snapshot';
import { TaskScheduleItemDetailComponent } from './task-schedule-item-detail.component';

@Component({
  selector: 'app-task-schedule-month-list',
  standalone: true,
  imports: [CommonModule, TranslateModule, TaskScheduleItemDetailComponent],
  template: `
    @if (!monthGroups.length) {
      <p class="plan-task-schedule-month-list__empty">{{
        'plans.task_schedules.list_empty' | translate
      }}</p>
    } @else {
      <div class="plan-task-schedule-month-list">
        @for (group of monthGroups; track group.monthKey) {
          <section
            class="plan-task-schedule-month-list__month"
            [attr.aria-label]="formatMonth(group.monthKey)"
          >
            <h3 class="plan-task-schedule-month-list__month-title">{{ formatMonth(group.monthKey) }}</h3>
            <ul class="plan-task-schedule-month-list__list" role="list">
              @for (row of group.rows; track row.item.item_id) {
                <li class="plan-task-schedule-month-list__item">
                  <button
                    type="button"
                    class="plan-task-schedule-month-list__row"
                    [class.plan-task-schedule-month-list__row--selected]="isSelected(row.item)"
                    (click)="selectTask(row.item)"
                  >
                    <span class="plan-task-schedule-month-list__date">{{
                      formatDay(row.item.scheduled_date!)
                    }}</span>
                    <span class="plan-task-schedule-month-list__name">{{ row.item.name }}</span>
                    <span class="plan-task-schedule-month-list__meta">{{
                      'plans.task_schedules.list_row_meta'
                        | translate: { field: row.fieldName, crop: row.cropName }
                    }}</span>
                    <span class="plan-task-schedule-month-list__status">{{
                      statusLabelKey(row) | translate
                    }}</span>
                  </button>
                </li>
              }
            </ul>
          </section>
        }
      </div>
      <app-task-schedule-item-detail [task]="$any(selectedTask)" />
    }
  `,
  styleUrls: ['./task-schedule-month-list.component.css']
})
export class TaskScheduleMonthListComponent {
  private readonly translate = inject(TranslateService);

  @Input({ required: true }) monthGroups: PlanTaskScheduleMonthGroupView[] = [];

  selectedTask: PlanTaskScheduleItem | null = null;

  formatDay(iso: string): string {
    return formatIsoDayForDisplay(iso, this.translate.currentLang);
  }

  formatMonth(monthKey: string): string {
    return formatIsoMonthForDisplay(monthKey, this.translate.currentLang);
  }

  statusLabelKey(row: CrossFarmScheduleRow): string {
    return `plans.task_schedules.status.${row.item.status.toLowerCase()}`;
  }

  selectTask(task: PlanTaskScheduleItem): void {
    if (this.selectedTask?.item_id === task.item_id) {
      this.selectedTask = null;
      return;
    }
    this.selectedTask = task;
  }

  isSelected(task: PlanTaskScheduleItem): boolean {
    return this.selectedTask?.item_id === task.item_id;
  }
}
