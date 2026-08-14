import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { LearningOrchestrationMode } from '../../domain/plans/learn-master-update-orchestration';
import { PlanLearnLoopProgressStripComponent } from './plan-learn-loop-progress-strip.component';

@Component({
  selector: 'app-plan-task-schedule-orchestration-banner',
  standalone: true,
  imports: [RouterLink, TranslateModule, PlanLearnLoopProgressStripComponent],
  template: `
    @if (mode) {
      <div class="learn-orchestration-banner" role="status" aria-live="polite">
        <p class="learn-orchestration-banner__message">
          {{ messageKey | translate }}
        </p>
        <p class="learn-orchestration-banner__hint">
          {{ hintKey | translate }}
        </p>
        <app-plan-learn-loop-progress-strip [planId]="planId" />
        @if (showWorkRetryLink) {
          <a class="btn-secondary learn-orchestration-banner__work-link" [routerLink]="workLink">
            {{ 'plans.task_schedules.orchestration.work_retry' | translate }}
          </a>
        }
        @if (showReturnToLearnLink) {
          <a class="btn-primary learn-orchestration-banner__learn-link" [routerLink]="learnLink">
            {{ 'plans.task_schedules.orchestration.return_to_learn' | translate }}
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
  @Input() orchestrationComplete = false;

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

  get showReturnToLearnLink(): boolean {
    return this.mode === 'regenerate' || this.mode === 'sync_verify';
  }

  get workLink(): (string | number)[] {
    return ['/plans', this.planId, 'work'];
  }

  get learnLink(): (string | number)[] {
    return ['/plans', this.planId, 'learn'];
  }
}
