import { Component, Input, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { FieldSchedule } from '../../models/plans/task-schedule';

@Component({
  selector: 'app-task-schedule-timeline',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <div class="timeline">
      @if (fields.length > 0) {
        @for (field of fields; track field.id) {
          <div class="field-section">
            <h3>{{ fieldHeading(field) }}</h3>

            <div class="schedule-columns">
              <div class="column">
                <h4>{{ 'plans.task_schedules.general_label' | translate }}</h4>
                <ul class="list">
                  @for (task of field.schedules.general; track task.item_id) {
                    <li class="item">
                      {{ task.name }}
                      <span class="badge badge--status" [class]="task.badge.type">{{
                        statusLabelKey(task.status) | translate
                      }}</span>
                      @if (task.completed) {
                        <span class="badge badge--done">✓</span>
                      }
                    </li>
                  }
                </ul>
              </div>

              <div class="column">
                <h4>{{ 'plans.task_schedules.fertilizer_label' | translate }}</h4>
                <ul class="list">
                  @for (task of field.schedules.fertilizer; track task.item_id) {
                    <li class="item">
                      {{ task.name }}
                      <span class="badge badge--status" [class]="task.badge.type">{{
                        statusLabelKey(task.status) | translate
                      }}</span>
                      @if (task.completed) {
                        <span class="badge badge--done">✓</span>
                      }
                    </li>
                  }
                </ul>
              </div>
            </div>
          </div>
        }
      } @else {
        <p>{{ 'plans.task_schedules.no_schedules' | translate }}</p>
      }
    </div>
  `,
  styleUrls: ['./task-schedule-timeline.component.css']
})
export class TaskScheduleTimelineComponent {
  private readonly translate = inject(TranslateService);

  @Input() fields: FieldSchedule[] = [];

  statusLabelKey(status: string): string {
    return `plans.task_schedules.status.${status.toLowerCase()}`;
  }

  fieldHeading(field: FieldSchedule): string {
    const fieldLabel = /^\d+$/.test(field.name.trim())
      ? this.translate.instant('plans.task_schedules.field_number', { number: field.name })
      : field.name;
    return this.translate.instant('plans.task_schedules.field_section', {
      name: fieldLabel,
      crop: field.crop_name
    });
  }
}
