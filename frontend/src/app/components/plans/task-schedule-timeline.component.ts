import { Component, Input, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDateForDisplay } from '../../core/format-display-date';
import { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';
import { TaskScheduleItemDetailComponent } from './task-schedule-item-detail.component';

@Component({
  selector: 'app-task-schedule-timeline',
  standalone: true,
  imports: [CommonModule, TranslateModule, RouterLink, TaskScheduleItemDetailComponent],
  template: `
    <div class="timeline-layout">
      <div class="timeline">
        @if (fields.length > 0) {
          @for (field of fields; track field.id) {
            <div class="field-section">
              @if (planId) {
                <h3>
                  <a class="field-section__plan-link" [routerLink]="['/plans', planId]">
                    {{ fieldHeading(field) }}
                  </a>
                </h3>
              } @else {
                <h3>{{ fieldHeading(field) }}</h3>
              }

              <div class="schedule-columns">
                <div class="column">
                  <h4>{{ 'plans.task_schedules.general_label' | translate }}</h4>
                  @if (sortedTasks(field.schedules.general).length) {
                    <ul class="list">
                      @for (task of sortedTasks(field.schedules.general); track task.item_id) {
                        <li>
                          <button
                            type="button"
                            class="item item--selectable"
                            [class.item--selected]="isSelected(task)"
                            (click)="selectTask(task)"
                          >
                            <span class="item__main">
                              <span class="item__name">{{ task.name }}</span>
                              @if (formatScheduledDate(task.scheduled_date); as dateLabel) {
                                <span class="item__date">{{ dateLabel }}</span>
                              }
                            </span>
                            <span class="item__badges">
                              <span class="badge badge--status" [class]="task.badge.type">{{
                                statusLabelKey(task.status) | translate
                              }}</span>
                              @if (task.completed) {
                                <span class="badge badge--done">✓</span>
                              }
                            </span>
                          </button>
                        </li>
                      }
                    </ul>
                  } @else {
                    <p class="column-empty">{{ 'plans.task_schedules.field_no_tasks' | translate }}</p>
                  }
                </div>

                <div class="column">
                  <h4>{{ 'plans.task_schedules.fertilizer_label' | translate }}</h4>
                  @if (sortedTasks(field.schedules.fertilizer).length) {
                    <ul class="list">
                      @for (task of sortedTasks(field.schedules.fertilizer); track task.item_id) {
                        <li>
                          <button
                            type="button"
                            class="item item--selectable"
                            [class.item--selected]="isSelected(task)"
                            (click)="selectTask(task)"
                          >
                            <span class="item__main">
                              <span class="item__name">{{ task.name }}</span>
                              @if (formatScheduledDate(task.scheduled_date); as dateLabel) {
                                <span class="item__date">{{ dateLabel }}</span>
                              }
                            </span>
                            <span class="item__badges">
                              <span class="badge badge--status" [class]="task.badge.type">{{
                                statusLabelKey(task.status) | translate
                              }}</span>
                              @if (task.completed) {
                                <span class="badge badge--done">✓</span>
                              }
                            </span>
                          </button>
                        </li>
                      }
                    </ul>
                  } @else {
                    <p class="column-empty">{{ 'plans.task_schedules.fertilizer_empty' | translate }}</p>
                  }
                </div>

                <div class="column">
                  <h4>{{ 'plans.task_schedules.unscheduled_title' | translate }}</h4>
                  @if (sortedTasks(field.schedules.unscheduled).length) {
                    <ul class="list">
                      @for (task of sortedTasks(field.schedules.unscheduled); track task.item_id) {
                        <li>
                          <button
                            type="button"
                            class="item item--selectable"
                            [class.item--selected]="isSelected(task)"
                            (click)="selectTask(task)"
                          >
                            <span class="item__main">
                              <span class="item__name">{{ task.name }}</span>
                              @if (formatScheduledDate(task.scheduled_date); as dateLabel) {
                                <span class="item__date">{{ dateLabel }}</span>
                              }
                            </span>
                            <span class="item__badges">
                              <span class="badge badge--status" [class]="task.badge.type">{{
                                statusLabelKey(task.status) | translate
                              }}</span>
                              @if (task.completed) {
                                <span class="badge badge--done">✓</span>
                              }
                            </span>
                          </button>
                        </li>
                      }
                    </ul>
                  } @else {
                    <p class="column-empty">{{ 'plans.task_schedules.field_no_tasks' | translate }}</p>
                  }
                </div>
              </div>
            </div>
          }
        } @else {
          <p>{{ 'plans.task_schedules.no_schedules' | translate }}</p>
        }
      </div>

      <app-task-schedule-item-detail [task]="selectedTask" />
    </div>
  `,
  styleUrls: ['./task-schedule-timeline.component.css']
})
export class TaskScheduleTimelineComponent {
  private readonly translate = inject(TranslateService);

  @Input() fields: FieldSchedule[] = [];
  @Input() planId: number | null = null;

  selectedTask: TaskScheduleItem | null = null;

  statusLabelKey(status: string): string {
    return `plans.task_schedules.status.${status.toLowerCase()}`;
  }

  selectTask(task: TaskScheduleItem): void {
    if (this.selectedTask?.item_id === task.item_id) {
      this.selectedTask = null;
      return;
    }
    this.selectedTask = task;
  }

  isSelected(task: TaskScheduleItem): boolean {
    return this.selectedTask?.item_id === task.item_id;
  }

  sortedTasks(tasks: TaskScheduleItem[]): TaskScheduleItem[] {
    return [...tasks].sort((a, b) => {
      if (!a.scheduled_date && !b.scheduled_date) {
        return 0;
      }
      if (!a.scheduled_date) {
        return 1;
      }
      if (!b.scheduled_date) {
        return -1;
      }
      return a.scheduled_date.localeCompare(b.scheduled_date);
    });
  }

  formatScheduledDate(iso: string | null): string | null {
    if (!iso) {
      return null;
    }
    return formatIsoDateForDisplay(iso, this.translate.currentLang);
  }

  fieldHeading(field: FieldSchedule): string {
    const fieldLabel = /^\d+$/.test(field.name.trim())
      ? this.translate.instant('plans.task_schedules.field_number', { number: field.name })
      : field.name;
    const base = this.translate.instant('plans.task_schedules.field_section', {
      name: fieldLabel,
      crop: field.crop_name
    });
    if (field.cultivation_start_date && field.cultivation_end_date) {
      const period = this.translate.instant('plans.task_schedules.cultivation_period', {
        start: formatIsoDateForDisplay(field.cultivation_start_date, this.translate.currentLang),
        end: formatIsoDateForDisplay(field.cultivation_end_date, this.translate.currentLang)
      });
      return `${base} — ${period}`;
    }
    return base;
  }
}
