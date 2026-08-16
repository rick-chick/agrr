import { Component, Input } from '@angular/core';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import {
  buildPlanCarryoverPreviewTableRows,
  type PlanCarryoverPreviewTableRow
} from '../../domain/plans/build-plan-carryover-preview-table-rows';
import { resolveCarryoverPreviewConfidence } from '../../domain/plans/resolve-carryover-preview-confidence';
import type { PlanVsActualCategorySummary, PlanVsActualSummary } from '../../domain/plans/plan-vs-actual-summary';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';
import { LearnProposalConfidenceBadgeComponent } from './learn-proposal-confidence-badge.component';

@Component({
  selector: 'app-plan-carryover-preview',
  standalone: true,
  imports: [TranslateModule, LearnProposalConfidenceBadgeComponent],
  template: `
    <div class="plan-carryover-preview">
      <div class="plan-carryover-preview__header">
        <h4 class="plan-carryover-preview__title">{{ titleKey | translate }}</h4>
        <app-learn-proposal-confidence-badge [confidence]="confidence" />
      </div>
      @if (rows.length) {
        <table class="plan-carryover-preview__table">
          <thead>
            <tr>
              <th scope="col">{{
                'plans.task_schedules.variance_subview.category_column' | translate
              }}</th>
              <th scope="col">{{
                'plans.task_schedules.variance_subview.category_average' | translate
              }}</th>
            </tr>
          </thead>
          <tbody>
            @for (row of rows; track row.track) {
              @if (row.kind === 'category') {
                <tr>
                  <td>{{ categoryLabel(row.category) }}</td>
                  <td>{{ categoryAverageLabel(row.category) }}</td>
                </tr>
              } @else {
                <tr>
                  <td>{{ row.labelKey | translate }}</td>
                  <td>{{ row.count }}</td>
                </tr>
              }
            }
          </tbody>
        </table>
      } @else {
        <p class="plan-carryover-preview__empty">{{ emptyKey | translate }}</p>
      }
    </div>
  `,
  styleUrls: ['./plan-carryover-preview.component.css']
})
export class PlanCarryoverPreviewComponent {
  @Input({ required: true }) summary!: PlanVsActualSummary;
  @Input() titleKey = 'plans.carryover.preview.title';
  @Input() emptyKey = 'plans.carryover.preview.empty';

  constructor(private readonly translate: TranslateService) {}

  get confidence(): ReturnType<typeof resolveCarryoverPreviewConfidence> {
    return resolveCarryoverPreviewConfidence(this.summary);
  }

  get rows(): PlanCarryoverPreviewTableRow[] {
    return buildPlanCarryoverPreviewTableRows(this.summary);
  }

  categoryLabel(category: PlanVsActualCategorySummary): string {
    return this.translate.instant(
      `plans.task_schedules.variance_subview.category.${category.category}`
    );
  }

  categoryAverageLabel(category: PlanVsActualCategorySummary): string {
    if (category.average_delta_days == null) {
      return this.translate.instant('plans.task_schedules.variance_subview.not_available');
    }
    return this.translate.instant('plans.task_schedules.variance_subview.average_value', {
      delta: formatPlanTaskScheduleAverageDeltaDaysLabel(category.average_delta_days)
    });
  }
}
