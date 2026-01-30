import { Component, Input, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { CdkDragDrop, DragDropModule, moveItemInArray, transferArrayItem } from '@angular/cdk/drag-drop';
import { FieldSchedule, TaskScheduleItem } from '../../models/plans/task-schedule';

@Component({
  selector: 'app-task-schedule-timeline',
  standalone: true,
  imports: [CommonModule, DragDropModule],
  template: `
    <div class="timeline">
      @if (fields.length > 0) {
        <div *ngFor="let field of fields" class="field-section">
          <h3>{{ field.name }} ({{ field.crop_name }})</h3>
          
          <div class="schedule-columns">
            <div class="column">
              <h4>General</h4>
              <div
                cdkDropList
                [cdkDropListData]="field.schedules.general"
                (cdkDropListDropped)="drop($event)"
                class="list"
              >
                <div class="item" *ngFor="let task of field.schedules.general" cdkDrag>
                  {{ task.name }}
                  <span class="badge" [class]="task.badge.type">{{ task.status }}</span>
                </div>
              </div>
            </div>

            <div class="column">
              <h4>Fertilizer</h4>
              <div
                cdkDropList
                [cdkDropListData]="field.schedules.fertilizer"
                (cdkDropListDropped)="drop($event)"
                class="list"
              >
                <div class="item" *ngFor="let task of field.schedules.fertilizer" cdkDrag>
                  {{ task.name }}
                </div>
              </div>
            </div>
          </div>
        </div>
      } @else {
        <p>No fields found in this plan.</p>
      }
    </div>
  `,
  styleUrl: './task-schedule-timeline.component.css'
})
export class TaskScheduleTimelineComponent {
  @Input() fields: FieldSchedule[] = [];

  drop(event: CdkDragDrop<TaskScheduleItem[]>) {
    if (event.previousContainer === event.container) {
      moveItemInArray(event.container.data, event.previousIndex, event.currentIndex);
    } else {
      transferArrayItem(
        event.previousContainer.data,
        event.container.data,
        event.previousIndex,
        event.currentIndex
      );
    }
  }
}
