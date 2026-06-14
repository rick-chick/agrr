import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';
import { FieldSchedule } from '../../models/plans/task-schedule';

@Component({
  selector: 'app-task-schedule-timeline',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <div class="timeline">
      @if (fields.length > 0) {
        <div *ngFor="let field of fields" class="field-section">
          <h3>{{ field.name }} ({{ field.crop_name }})</h3>

          <div class="schedule-columns">
            <div class="column">
              <h4>{{ 'plans.task_schedules.general_label' | translate }}</h4>
              <ul class="list">
                @for (task of field.schedules.general; track task.item_id) {
                  <li class="item">
                    {{ task.name }}
                    <span class="badge" [class]="task.badge.type">{{ task.status }}</span>
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
                    @if (task.completed) {
                      <span class="badge badge--done">✓</span>
                    }
                  </li>
                }
              </ul>
            </div>
          </div>
        </div>
      } @else {
        <p>{{ 'plans.task_schedules.no_schedules' | translate }}</p>
      }
    </div>
  `,
  styleUrls: ['./task-schedule-timeline.component.css']
})
export class TaskScheduleTimelineComponent {
  @Input() fields: FieldSchedule[] = [];
}
