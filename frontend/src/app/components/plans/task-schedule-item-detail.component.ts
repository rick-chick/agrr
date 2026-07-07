import { Component, Input, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDateForDisplay } from '../../core/format-display-date';
import { TaskScheduleItem } from '../../models/plans/task-schedule';

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

  @Input() task: TaskScheduleItem | null = null;

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
    const stageName = this.task?.details.stage.name?.trim();
    if (!stageName) {
      return this.notApplicable;
    }
    return stageName;
  }

  get gddLabel(): string {
    const trigger = this.task?.details.gdd.trigger;
    const tolerance = this.task?.details.gdd.tolerance;
    if (!trigger && !tolerance) {
      return this.notApplicable;
    }
    if (trigger && tolerance) {
      return `${trigger} (±${tolerance})`;
    }
    return trigger ?? tolerance ?? this.notApplicable;
  }

  get amountLabel(): string {
    const amount = this.task?.details.amount?.trim();
    if (!amount) {
      return this.notApplicable;
    }
    const unit = this.task?.details.amount_unit?.trim();
    return unit ? `${amount} ${unit}` : amount;
  }

  get masterNameLabel(): string {
    const name = this.task?.details.master?.name?.trim();
    return name || this.notApplicable;
  }

  get masterDescriptionLabel(): string {
    const description = this.task?.details.master?.description?.trim();
    return description || this.notApplicable;
  }
}
