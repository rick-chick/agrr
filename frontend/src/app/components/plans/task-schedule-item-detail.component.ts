import { Component, Input, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDateForDisplay } from '../../core/format-display-date';
import type { PlanTaskScheduleItem } from '../../domain/work-schedule/plan-schedule-snapshot';

@Component({
  selector: 'app-task-schedule-item-detail',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <aside class="task-detail-panel" aria-live="polite">
      <h4 class="task-detail-panel__title">{{ 'plans.task_schedules.detail.title' | translate }}</h4>
      @if (task) {
        <dl class="task-detail-panel__list">
          <div class="task-detail-panel__row">
            <dt class="task-detail-panel__label">
              {{ 'plans.task_schedules.detail.scheduled_date' | translate }}
            </dt>
            <dd class="task-detail-panel__value">{{ scheduledDateLabel }}</dd>
          </div>
          <div class="task-detail-panel__row">
            <dt class="task-detail-panel__label">
              {{ 'plans.task_schedules.detail.stage' | translate }}
            </dt>
            <dd class="task-detail-panel__value">{{ stageLabel }}</dd>
          </div>
          <div class="task-detail-panel__row">
            <dt class="task-detail-panel__label">{{ 'crops.show.gdd_trigger' | translate }}</dt>
            <dd class="task-detail-panel__value">{{ gddLabel }}</dd>
          </div>
          <div class="task-detail-panel__row">
            <dt class="task-detail-panel__label">
              {{ 'plans.task_schedules.detail.amount' | translate }}
            </dt>
            <dd class="task-detail-panel__value">{{ amountLabel }}</dd>
          </div>
          <div class="task-detail-panel__row">
            <dt class="task-detail-panel__label">
              {{ 'plans.task_schedules.detail.master_name' | translate }}
            </dt>
            <dd class="task-detail-panel__value">{{ masterNameLabel }}</dd>
          </div>
          <div class="task-detail-panel__row">
            <dt class="task-detail-panel__label">
              {{ 'plans.task_schedules.detail.master_description' | translate }}
            </dt>
            <dd class="task-detail-panel__value">{{ masterDescriptionLabel }}</dd>
          </div>
        </dl>
      } @else {
        <p class="task-detail-panel__empty">{{ 'plans.task_schedules.detail.empty' | translate }}</p>
      }
    </aside>
  `,
  styleUrls: ['./task-schedule-item-detail.component.css']
})
export class TaskScheduleItemDetailComponent {
  private readonly translate = inject(TranslateService);

  @Input() task: PlanTaskScheduleItem | null = null;

  get notApplicable(): string {
    return this.translate.instant('plans.task_schedules.detail.not_applicable');
  }

  get scheduledDateLabel(): string {
    if (!this.task?.scheduled_date) {
      return this.notApplicable;
    }
    return formatIsoDateForDisplay(this.task.scheduled_date, this.translate.currentLang);
  }

  get stageLabel(): string {
    const stageName = this.task?.details.stageName;
    if (!stageName) {
      return this.notApplicable;
    }
    return stageName;
  }

  get gddLabel(): string {
    const trigger = this.task?.details.gddTrigger;
    const tolerance = this.task?.details.gddTolerance;
    if (!trigger && !tolerance) {
      return this.notApplicable;
    }
    if (trigger && tolerance) {
      return `${trigger} (±${tolerance})`;
    }
    return trigger ?? tolerance ?? this.notApplicable;
  }

  get amountLabel(): string {
    const amount = this.task?.details.amount;
    if (!amount) {
      return this.notApplicable;
    }
    const unit = this.task?.details.amountUnit;
    return unit ? `${amount} ${unit}` : amount;
  }

  get masterNameLabel(): string {
    return this.task?.details.masterName || this.notApplicable;
  }

  get masterDescriptionLabel(): string {
    return this.task?.details.masterDescription || this.notApplicable;
  }
}
