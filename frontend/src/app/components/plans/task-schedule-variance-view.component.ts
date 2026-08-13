import { Component, Input, inject } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { formatIsoDateForDisplay } from '../../core/format-display-date';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';
import type {
  PlanVsActualCategorySummary,
  PlanVsActualItem,
  PlanVsActualPlanSummaryStats
} from '../../domain/plans/plan-vs-actual-summary';
import type { PlanTaskScheduleRowView } from './plan-task-schedule.view';

@Component({
  selector: 'app-task-schedule-variance-view',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    @if (loading) {
      <p class="master-loading">{{ 'common.loading' | translate }}</p>
    } @else if (error) {
      <div class="page-alert-error plan-work__error" role="alert">
        <p>{{ error | translate }}</p>
      </div>
    } @else if (stats && summary) {
      <section class="task-schedule-variance__summary" aria-labelledby="task-schedule-variance-summary">
        <h3 id="task-schedule-variance-summary" class="task-schedule-variance__section-title">
          {{ 'plans.task_schedules.variance_subview.summary_title' | translate }}
        </h3>
        <dl class="task-schedule-variance__summary-grid">
          <div>
            <dt>{{ 'plans.task_schedules.variance_subview.summary_completed' | translate }}</dt>
            <dd>{{ stats.completedCount }}</dd>
          </div>
          <div>
            <dt>{{ 'plans.task_schedules.variance_subview.summary_average_delta' | translate }}</dt>
            <dd>{{ averageDeltaLabel(stats.averageDeltaDays) }}</dd>
          </div>
          <div>
            <dt>{{ 'plans.task_schedules.variance_subview.summary_unrecorded' | translate }}</dt>
            <dd>{{ stats.unrecordedCount }}</dd>
          </div>
        </dl>
      </section>

      @if (summary.categories.length) {
        <section class="task-schedule-variance__section" aria-labelledby="task-schedule-variance-categories">
          <h3 id="task-schedule-variance-categories" class="task-schedule-variance__section-title">
            {{ 'plans.task_schedules.variance_subview.categories_title' | translate }}
          </h3>
          <table class="task-schedule-variance__table">
            <thead>
              <tr>
                <th scope="col">{{
                  'plans.task_schedules.variance_subview.category_column' | translate
                }}</th>
                <th scope="col">{{
                  'plans.task_schedules.variance_subview.category_average' | translate
                }}</th>
                <th scope="col">{{
                  'plans.task_schedules.variance_subview.category_recorded' | translate
                }}</th>
              </tr>
            </thead>
            <tbody>
              @for (category of summary.categories; track category.category) {
                <tr>
                  <td>{{ categoryLabel(category) }}</td>
                  <td>{{ categoryAverageLabel(category) }}</td>
                  <td>{{ category.recorded_count }} / {{ category.item_count }}</td>
                </tr>
              }
            </tbody>
          </table>
        </section>
      }

      @if (summary.top_variance_items.length) {
        <section class="task-schedule-variance__section" aria-labelledby="task-schedule-variance-top">
          <h3 id="task-schedule-variance-top" class="task-schedule-variance__section-title">
            {{ 'plans.task_schedules.variance_subview.top_variance_title' | translate }}
          </h3>
          <ul class="task-schedule-variance__list" role="list">
            @for (item of summary.top_variance_items; track item.item_id) {
              <li class="task-schedule-variance__list-item">
                <div class="task-schedule-variance__list-main">
                  <span class="task-schedule-variance__list-name">{{ item.name }}</span>
                  <span class="task-schedule-variance__list-meta">{{
                    topItemMeta(item)
                  }}</span>
                </div>
                <span class="task-schedule-variance__list-delta">{{ itemDeltaLabel(item) }}</span>
                <a
                  class="task-schedule-variance__list-link"
                  [routerLink]="['/plans', planId]"
                  [queryParams]="{ field_cultivation_id: item.field_cultivation_id }"
                >{{ 'plans.task_schedules.variance_subview.open_workbench' | translate }}</a>
              </li>
            }
          </ul>
        </section>
      }

      @if (unrecordedRows.length) {
        <section class="task-schedule-variance__section" aria-labelledby="task-schedule-variance-unrecorded">
          <h3 id="task-schedule-variance-unrecorded" class="task-schedule-variance__section-title">
            {{ 'plans.task_schedules.variance_subview.unrecorded_title' | translate }}
          </h3>
          <ul class="task-schedule-variance__list" role="list">
            @for (row of unrecordedRows; track row.item.item_id) {
              <li class="task-schedule-variance__list-item">
                <div class="task-schedule-variance__list-main">
                  <span class="task-schedule-variance__list-name">{{ row.item.name }}</span>
                  <span class="task-schedule-variance__list-meta">{{
                    'plans.task_schedules.list_row_meta'
                      | translate: { field: row.fieldName, crop: row.cropName }
                  }}</span>
                  @if (row.item.scheduled_date) {
                    <span class="task-schedule-variance__list-date">{{
                      formatDate(row.item.scheduled_date)
                    }}</span>
                  }
                </div>
                <a
                  class="task-schedule-variance__list-link"
                  [routerLink]="['/plans', planId, 'task_schedule']"
                  [queryParams]="scheduleLinkQuery(row)"
                >{{ 'plans.task_schedules.variance_subview.open_in_schedule' | translate }}</a>
              </li>
            }
          </ul>
        </section>
      }

      @if (
        !summary.categories.length &&
        !summary.top_variance_items.length &&
        !unrecordedRows.length
      ) {
        <p class="task-schedule-variance__empty" role="status">
          {{ 'plans.task_schedules.variance_subview.no_data' | translate }}
        </p>
      }
    }
  `,
  styleUrls: ['./task-schedule-variance-view.component.css']
})
export class TaskScheduleVarianceViewComponent {
  private readonly translate = inject(TranslateService);

  @Input({ required: true }) planId!: number;
  @Input() loading = false;
  @Input() error: string | null = null;
  @Input() stats: PlanVsActualPlanSummaryStats | null = null;
  @Input() summary = null as {
    categories: PlanVsActualCategorySummary[];
    top_variance_items: PlanVsActualItem[];
  } | null;
  @Input() unrecordedRows: PlanTaskScheduleRowView[] = [];

  averageDeltaLabel(value: number | null): string {
    if (value == null) {
      return this.translate.instant('plans.task_schedules.variance_subview.not_available');
    }
    return this.translate.instant('plans.task_schedules.variance_subview.average_value', {
      delta: formatPlanTaskScheduleAverageDeltaDaysLabel(value)
    });
  }

  categoryAverageLabel(category: PlanVsActualCategorySummary): string {
    return this.averageDeltaLabel(category.average_delta_days);
  }

  categoryLabel(category: PlanVsActualCategorySummary): string {
    return this.translate.instant(this.categoryLabelKey(category.category));
  }

  categoryLabelKey(category: string): string {
    return `plans.task_schedules.variance_subview.category.${category}`;
  }

  itemDeltaLabel(item: PlanVsActualItem): string {
    if (item.delta_days == null) {
      return this.translate.instant('plans.task_schedules.variance_subview.not_available');
    }
    const sign = item.delta_days > 0 ? '+' : '';
    return this.translate.instant('plans.task_schedules.variance_subview.delta_value', {
      delta: `${sign}${item.delta_days}`
    });
  }

  topItemMeta(item: PlanVsActualItem): string {
    const scheduled = item.scheduled_date
      ? this.formatDate(item.scheduled_date)
      : this.translate.instant('plans.task_schedules.variance_subview.not_available');
    const actual = item.actual_date
      ? this.formatDate(item.actual_date)
      : this.translate.instant('plans.task_schedules.variance_subview.not_available');
    return this.translate.instant('plans.task_schedules.variance_subview.top_item_dates', {
      scheduled,
      actual
    });
  }

  formatDate(value: string): string {
    return formatIsoDateForDisplay(value, this.translate.currentLang);
  }

  scheduleLinkQuery(row: PlanTaskScheduleRowView): Record<string, string | number | null> {
    return {
      field_cultivation_id: row.fieldCultivationId,
      from_date: row.item.scheduled_date
    };
  }
}
