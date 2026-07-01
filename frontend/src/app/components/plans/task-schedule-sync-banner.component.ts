import { CommonModule } from '@angular/common';
import { Component, EventEmitter, Input, Output } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { TaskScheduleSyncState } from '../../models/plans/task-schedule';

@Component({
  selector: 'app-task-schedule-sync-banner',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    @if (visible) {
      <div [class]="bannerClass" role="status" aria-live="polite">
        <p>{{ messageKey | translate }}</p>
        @if (syncState === 'failed' && syncError) {
          <p class="task-schedule-sync-banner__detail">{{ syncError | translate }}</p>
        }
        @if (regenerateError) {
          <p class="task-schedule-sync-banner__detail">{{ regenerateError | translate }}</p>
        }
        @if (showRetry) {
          <button
            type="button"
            class="btn-secondary task-schedule-sync-banner__retry"
            [disabled]="regenerating"
            (click)="retry.emit()"
          >
            {{
              (regenerating ? 'common.loading' : 'plans.task_schedules.sync_retry') | translate
            }}
          </button>
        }
      </div>
    }
  `,
  styleUrls: ['./task-schedule-sync-banner.component.css']
})
export class TaskScheduleSyncBannerComponent {
  @Input({ required: true }) syncState!: TaskScheduleSyncState | string;
  @Input() syncError: string | null = null;
  @Input() regenerating = false;
  @Input() regenerateError: string | null = null;
  @Output() retry = new EventEmitter<void>();

  get visible(): boolean {
    return (
      this.syncState === 'never' ||
      this.syncState === 'failed' ||
      this.syncState === 'generating' ||
      this.syncState === 'stale'
    );
  }

  get showRetry(): boolean {
    return this.syncState !== 'generating' && this.syncState !== 'stale';
  }

  get bannerClass(): string {
    if (this.syncState === 'failed' || this.regenerateError) {
      return 'page-alert-error task-schedule-sync-banner';
    }
    if (this.syncState === 'stale') {
      return 'page-alert-warning task-schedule-sync-banner';
    }
    return 'page-alert-info task-schedule-sync-banner';
  }

  get messageKey(): string {
    return `plans.task_schedules.sync_${this.syncState}`;
  }
}
