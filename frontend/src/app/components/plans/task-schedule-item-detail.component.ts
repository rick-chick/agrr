import { Component, Input, inject } from '@angular/core';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import type { PlanTaskScheduleItem } from '../../domain/work-schedule/plan-schedule-snapshot';

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
}
