import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { LearningOrchestrationMode } from '../../domain/plans/learn-master-update-orchestration';

@Component({
  selector: 'app-plan-task-schedule-orchestration-banner',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    @if (mode) {
      <div class="learn-orchestration-banner" role="status" aria-live="polite">
        <p class="learn-orchestration-banner__message">
          {{ messageKey | translate }}
        </p>
        <p class="learn-orchestration-banner__hint">
          {{ hintKey | translate }}
        </p>
        @if (showWorkRetryLink) {
          <a class="btn-secondary learn-orchestration-banner__work-link" [routerLink]="workLink">
            {{ 'plans.task_schedules.orchestration.work_retry' | translate }}
          </a>
        }
      </div>
    }
  `,
  styleUrls: ['./plan-task-schedule-orchestration-banner.component.css']
})
export class PlanTaskScheduleOrchestrationBannerComponent {
  @Input({ required: true }) planId!: number;
  @Input() mode: LearningOrchestrationMode | null = null;
  @Input() syncState: string | null = null;

  get messageKey(): string {
    if (this.mode === 'regenerate') {
      return 'plans.task_schedules.orchestration.regenerate.message';
    }
    return 'plans.task_schedules.orchestration.sync_verify.message';
  }

  get hintKey(): string {
    if (this.mode === 'regenerate') {
      return 'plans.task_schedules.orchestration.regenerate.hint';
    }
    return 'plans.task_schedules.orchestration.sync_verify.hint';
  }

  get showWorkRetryLink(): boolean {
    return this.mode === 'sync_verify' && this.syncState === 'failed';
  }

  get workLink(): (string | number)[] {
    return ['/plans', this.planId, 'work'];
  }
}
