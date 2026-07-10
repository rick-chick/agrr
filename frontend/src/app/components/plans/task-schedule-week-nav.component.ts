import { Component, EventEmitter, Input, Output, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDateForDisplay } from '../../core/format-display-date';
import type { TaskScheduleMinimap, WeekInfo } from '../../models/plans/task-schedule';

export type TaskScheduleViewMode = 'plan' | 'week';

function addWeeks(isoDate: string, weeks: number): string {
  const [y, m, d] = isoDate.split('-').map(Number);
  const date = new Date(y, m - 1, d);
  date.setDate(date.getDate() + weeks * 7);
  const ny = date.getFullYear();
  const nm = String(date.getMonth() + 1).padStart(2, '0');
  const nd = String(date.getDate()).padStart(2, '0');
  return `${ny}-${nm}-${nd}`;
}

function adjacentWeekStart(
  current: string,
  direction: 'prev' | 'next',
  minimap: TaskScheduleMinimap | null
): string {
  const weeks = minimap?.weeks ?? [];
  if (weeks.length > 0) {
    const sorted = [...weeks].sort((a, b) => a.start_date.localeCompare(b.start_date));
    const idx = sorted.findIndex((week) => week.start_date === current);
    if (idx >= 0) {
      const nextIdx = direction === 'prev' ? idx - 1 : idx + 1;
      if (nextIdx >= 0 && nextIdx < sorted.length) {
        return sorted[nextIdx].start_date;
      }
    }
  }
  return addWeeks(current, direction === 'prev' ? -1 : 1);
}

@Component({
  selector: 'app-task-schedule-week-nav',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <div class="task-schedule-week-nav">
      <div class="task-schedule-week-nav__modes" role="tablist" aria-label="View mode">
        <button
          type="button"
          class="btn btn-secondary btn-sm task-schedule-week-nav__mode"
          [class.active]="viewMode === 'plan'"
          role="tab"
          [attr.aria-selected]="viewMode === 'plan'"
          (click)="selectMode('plan')"
        >
          {{ 'plans.task_schedules.view_mode_plan' | translate }}
        </button>
        <button
          type="button"
          class="btn btn-secondary btn-sm task-schedule-week-nav__mode"
          [class.active]="viewMode === 'week'"
          role="tab"
          [attr.aria-selected]="viewMode === 'week'"
          (click)="selectMode('week')"
        >
          {{ 'plans.task_schedules.view_mode_week' | translate }}
        </button>
      </div>

      @if (viewMode === 'week' && week) {
        <div class="task-schedule-week-nav__week-controls">
          <p class="task-schedule-week-nav__label">{{ weekLabel }}</p>
          <div class="task-schedule-week-nav__actions">
            <button
              type="button"
              class="btn btn-secondary btn-sm task-schedule-week-nav__prev"
              (click)="goPrevWeek()"
            >
              {{ 'plans.task_schedules.nav_prev_week' | translate }}
            </button>
            <button
              type="button"
              class="btn btn-secondary btn-sm task-schedule-week-nav__today"
              (click)="goToday()"
            >
              {{ 'plans.task_schedules.nav_today' | translate }}
            </button>
            <button
              type="button"
              class="btn btn-secondary btn-sm task-schedule-week-nav__next"
              (click)="goNextWeek()"
            >
              {{ 'plans.task_schedules.nav_next_week' | translate }}
            </button>
          </div>
          @if (minimapWeeks.length > 0) {
            <div class="task-schedule-week-nav__chips" role="group" aria-label="Week picker">
              @for (chip of minimapWeeks; track chip.start_date) {
                <button
                  type="button"
                  class="btn btn-white btn-sm task-schedule-week-nav__chip"
                  [class.active]="chip.start_date === week.start_date"
                  (click)="selectWeek(chip.start_date)"
                >
                  {{ chip.label }}
                </button>
              }
            </div>
          }
        </div>
      }
    </div>
  `,
  styleUrls: ['./task-schedule-week-nav.component.css']
})
export class TaskScheduleWeekNavComponent {
  private readonly translate = inject(TranslateService);

  @Input({ required: true }) viewMode!: TaskScheduleViewMode;
  @Input() week: WeekInfo | null = null;
  @Input() minimap: TaskScheduleMinimap | null = null;

  @Output() readonly viewModeChange = new EventEmitter<TaskScheduleViewMode>();
  @Output() readonly weekChange = new EventEmitter<string>();
  @Output() readonly weekToday = new EventEmitter<void>();

  get minimapWeeks(): TaskScheduleMinimap['weeks'] {
    const weeks = this.minimap?.weeks ?? [];
    return [...weeks].sort((a, b) => a.start_date.localeCompare(b.start_date));
  }

  get weekLabel(): string {
    if (!this.week) {
      return '';
    }
    const start = formatIsoDateForDisplay(this.week.start_date, this.translate.currentLang);
    const end = formatIsoDateForDisplay(this.week.end_date, this.translate.currentLang);
    return this.translate.instant('plans.task_schedules.week_label', { start, end });
  }

  selectMode(mode: TaskScheduleViewMode): void {
    if (mode !== this.viewMode) {
      this.viewModeChange.emit(mode);
    }
  }

  goPrevWeek(): void {
    if (!this.week) {
      return;
    }
    this.weekChange.emit(adjacentWeekStart(this.week.start_date, 'prev', this.minimap));
  }

  goNextWeek(): void {
    if (!this.week) {
      return;
    }
    this.weekChange.emit(adjacentWeekStart(this.week.start_date, 'next', this.minimap));
  }

  goToday(): void {
    this.weekToday.emit();
  }

  selectWeek(weekStart: string): void {
    this.weekChange.emit(weekStart);
  }
}
