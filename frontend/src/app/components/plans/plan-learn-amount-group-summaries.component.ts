import { Component, Input } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import type { PlanVsActualAmountGroupSummary } from '../../domain/plans/plan-vs-actual-summary';
import {
  amountGroupSummaryAnchorId,
  bpAmountProposalAnchorId
} from '../../domain/plans/amount-group-summary-anchor';
import { formatPlanTaskScheduleAmountDeltaLabel } from '../../domain/work-schedule/format-plan-task-schedule-amount-delta';

@Component({
  selector: 'app-plan-learn-amount-group-summaries',
  standalone: true,
  imports: [TranslateModule],
  template: `
    <section
      class="plan-learn-amount-group-summaries"
      aria-labelledby="plan-learn-amount-group-summaries-title"
    >
      <h3 id="plan-learn-amount-group-summaries-title" class="plan-learn-amount-group-summaries__title">
        {{ 'plans.learn.amount_group_summaries.title' | translate }}
      </h3>
      <p class="plan-learn-amount-group-summaries__lead">
        {{ 'plans.learn.amount_group_summaries.lead' | translate }}
      </p>

      @if (loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (summaries.length === 0) {
        <p class="plan-learn-amount-group-summaries__empty">
          {{ 'plans.learn.amount_group_summaries.empty' | translate }}
        </p>
      } @else {
        <table class="plan-learn-amount-group-summaries__table">
          <thead>
            <tr>
              <th scope="col">{{ 'plans.learn.amount_group_summaries.stage_column' | translate }}</th>
              <th scope="col">
                {{ 'plans.learn.amount_group_summaries.category_column' | translate }}
              </th>
              <th scope="col">
                {{ 'plans.learn.amount_group_summaries.task_type_column' | translate }}
              </th>
              <th scope="col">{{ 'plans.learn.amount_group_summaries.delta_column' | translate }}</th>
              <th scope="col">
                {{ 'plans.learn.amount_group_summaries.recorded_column' | translate }}
              </th>
              <th scope="col">
                <span class="visually-hidden">
                  {{ 'plans.learn.amount_group_summaries.view_proposal' | translate }}
                </span>
              </th>
            </tr>
          </thead>
          <tbody>
            @for (row of summaries; track rowKey(row)) {
              <tr [attr.data-stage-order]="row.stage_order">
                <td>
                  @if (row.stage_order == null) {
                    {{ 'plans.learn.amount_group_summaries.stage_unassigned' | translate }}
                  } @else {
                    {{
                      'plans.learn.amount_group_summaries.stage_label'
                        | translate: { order: row.stage_order, name: row.stage_name ?? '' }
                    }}
                  }
                </td>
                <td>{{ categoryLabel(row.category) | translate }}</td>
                <td>{{ taskTypeLabel(row.task_type) | translate }}</td>
                <td>{{ deltaLabel(row) }}</td>
                <td>{{ row.recorded_item_count }}</td>
                <td>
                  <a
                    class="plan-learn-amount-group-summaries__proposal-link"
                    [href]="proposalAnchorHref(row)"
                  >
                    {{ 'plans.learn.amount_group_summaries.view_proposal' | translate }}
                  </a>
                </td>
              </tr>
            }
          </tbody>
        </table>
      }
    </section>
  `,
  styleUrls: ['./plan-learn-amount-group-summaries.component.css']
})
export class PlanLearnAmountGroupSummariesComponent {
  @Input() summaries: PlanVsActualAmountGroupSummary[] = [];
  @Input() loading = false;

  rowKey(row: PlanVsActualAmountGroupSummary): string {
    return amountGroupSummaryAnchorId(row.stage_order, row.category, row.task_type);
  }

  categoryLabel(category: string): string {
    return `plans.learn.bp_amount_adjustment.category.${category}`;
  }

  taskTypeLabel(taskType: string): string {
    return `plans.learn.bp_amount_adjustment.task_type.${taskType}`;
  }

  deltaLabel(row: PlanVsActualAmountGroupSummary): string {
    if (row.average_amount_delta == null) {
      return '—';
    }
    return formatPlanTaskScheduleAmountDeltaLabel(row.average_amount_delta, row.amount_unit);
  }

  proposalAnchorHref(row: PlanVsActualAmountGroupSummary): string {
    return `#${bpAmountProposalAnchorId(row.stage_order, row.category, row.task_type)}`;
  }
}
