import { Component, Input, inject } from '@angular/core';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDateForDisplay } from '../../core/format-display-date';
import type { PlanTaskScheduleItem } from '../../domain/work-schedule/plan-schedule-snapshot';
import { formatPlanTaskScheduleDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';
import { resolvePlanTaskScheduleVarianceBadge } from '../../domain/work-schedule/resolve-plan-task-schedule-variance-badge';

@Component({
  selector: 'app-task-schedule-item-detail',
  standalone: true,
  imports: [TranslateModule],
  template: `
    @if (task) {
      <dl class="task-schedule-detail__facts">
        <div class="task-schedule-detail__fact">
          <dt class="task-schedule-detail__term">
            {{ 'plans.task_schedules.detail.stage' | translate }}
          </dt>
          <dd class="task-schedule-detail__value">{{ stageLabel }}</dd>
        </div>
        <div class="task-schedule-detail__fact">
          <dt class="task-schedule-detail__term">
            {{ 'plans.task_schedules.detail.amount' | translate }}
          </dt>
          <dd class="task-schedule-detail__value">{{ amountLabel }}</dd>
        </div>
        <div class="task-schedule-detail__fact task-schedule-detail__fact--wide">
          <dt class="task-schedule-detail__term">
            {{ 'plans.task_schedules.detail.master_description' | translate }}
          </dt>
          <dd class="task-schedule-detail__value">{{ masterDescriptionLabel }}</dd>
        </div>
      </dl>

      <section class="task-schedule-detail__variance" aria-labelledby="task-schedule-variance-heading">
        <h4 id="task-schedule-variance-heading" class="task-schedule-detail__variance-title">
          {{ 'plans.task_schedules.detail.variance_heading' | translate }}
        </h4>
        <dl class="task-schedule-detail__facts task-schedule-detail__facts--variance">
          <div class="task-schedule-detail__fact">
            <dt class="task-schedule-detail__term">
              {{ 'plans.task_schedules.detail.scheduled_date' | translate }}
            </dt>
            <dd class="task-schedule-detail__value">{{ scheduledDateLabel }}</dd>
          </div>
          <div class="task-schedule-detail__fact">
            <dt class="task-schedule-detail__term">
              {{ 'plans.task_schedules.detail.actual_date' | translate }}
            </dt>
            <dd class="task-schedule-detail__value">{{ actualDateLabel }}</dd>
          </div>
          <div class="task-schedule-detail__fact">
            <dt class="task-schedule-detail__term">
              {{ 'plans.task_schedules.detail.delta_days' | translate }}
            </dt>
            <dd class="task-schedule-detail__value">{{ deltaDaysLabel }}</dd>
          </div>
          @if (showGddComparison) {
            <div class="task-schedule-detail__fact">
              <dt class="task-schedule-detail__term">
                {{ 'plans.task_schedules.detail.planned_gdd' | translate }}
              </dt>
              <dd class="task-schedule-detail__value">{{ plannedGddLabel }}</dd>
            </div>
            <div class="task-schedule-detail__fact">
              <dt class="task-schedule-detail__term">
                {{ 'plans.task_schedules.detail.actual_gdd' | translate }}
              </dt>
              <dd class="task-schedule-detail__value">{{ actualGddLabel }}</dd>
            </div>
            <div class="task-schedule-detail__fact">
              <dt class="task-schedule-detail__term">
                {{ 'plans.task_schedules.detail.gdd_delta' | translate }}
              </dt>
              <dd class="task-schedule-detail__value">{{ gddDeltaLabel }}</dd>
            </div>
          }
        </dl>
      </section>
    } @else {
      <p class="task-schedule-detail__empty">{{ 'plans.task_schedules.detail.empty' | translate }}</p>
    }
  `,
  styleUrls: ['./task-schedule-item-detail.component.css']
})
export class TaskScheduleItemDetailComponent {
  private readonly translate = inject(TranslateService);

  @Input() task: PlanTaskScheduleItem | null = null;

  get notApplicable(): string {
    return this.translate.instant('plans.task_schedules.detail.not_applicable');
  }

  get stageLabel(): string {
    return this.task?.details.stageName || this.notApplicable;
  }

  get amountLabel(): string {
    const amount = this.task?.details.amount;
    if (!amount) {
      return this.notApplicable;
    }
    const unit = this.task?.details.amountUnit;
    return unit ? `${amount} ${unit}` : amount;
  }

  get masterDescriptionLabel(): string {
    return this.task?.details.masterDescription || this.notApplicable;
  }

  get scheduledDateLabel(): string {
    if (!this.task?.scheduled_date) {
      return this.notApplicable;
    }
    return formatIsoDateForDisplay(this.task.scheduled_date, this.translate.currentLang);
  }

  get actualDateLabel(): string {
    if (!this.task?.actualDate) {
      return this.notApplicable;
    }
    return formatIsoDateForDisplay(this.task.actualDate, this.translate.currentLang);
  }

  get deltaDaysLabel(): string {
    if (!this.task) {
      return this.notApplicable;
    }
    const badge = resolvePlanTaskScheduleVarianceBadge(this.task);
    if (!badge) {
      return this.notApplicable;
    }
    return formatPlanTaskScheduleDeltaDaysLabel(badge);
  }

  get showGddComparison(): boolean {
    return this.task?.gddAtActual != null;
  }

  get plannedGddLabel(): string {
    if (this.task?.gddTrigger == null) {
      return this.notApplicable;
    }
    return String(this.task.gddTrigger);
  }

  get actualGddLabel(): string {
    if (this.task?.gddAtActual == null) {
      return this.notApplicable;
    }
    return String(this.task.gddAtActual);
  }

  get gddDeltaLabel(): string {
    if (this.task?.gddDelta == null) {
      return this.notApplicable;
    }
    const delta = this.task.gddDelta;
    if (delta === 0) {
      return '±0';
    }
    return delta > 0 ? `+${delta}` : `${delta}`;
  }
}
