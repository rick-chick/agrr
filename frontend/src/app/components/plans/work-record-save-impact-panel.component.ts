import { Component, EventEmitter, Input, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';
import type { WorkRecordSaveImpactViewModel } from '../../domain/plans/work-record-save-impact';

@Component({
  selector: 'app-work-record-save-impact-panel',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    <section
      class="work-record-save-impact"
      role="status"
      aria-live="polite"
      aria-labelledby="work-record-save-impact-title"
    >
      <div class="work-record-save-impact__header">
        <h3 id="work-record-save-impact-title" class="work-record-save-impact__title">
          {{ 'plans.work.save_impact.title' | translate }}
        </h3>
        <button
          type="button"
          class="work-record-save-impact__dismiss"
          (click)="dismiss.emit()"
          [attr.aria-label]="'plans.work.save_impact.dismiss' | translate"
        >
          ×
        </button>
      </div>

      @if (loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (error) {
        <div class="page-alert-error" role="alert">
          <p>{{ error | translate }}</p>
        </div>
      } @else if (impact) {
        <dl class="work-record-save-impact__grid">
          <div>
            <dt>{{ 'plans.work.save_impact.task_label' | translate }}</dt>
            <dd>{{ impact.taskName }}</dd>
          </div>
          @if (impact.deltaDays != null) {
            <div>
              <dt>{{ 'plans.work.save_impact.delta_days' | translate }}</dt>
              <dd>{{ impact.deltaDays }}</dd>
            </div>
          }
          @if (impact.gddDelta != null) {
            <div>
              <dt>{{ 'plans.work.save_impact.gdd_delta' | translate }}</dt>
              <dd>{{ impact.gddDelta }}</dd>
            </div>
          }
          <div>
            <dt>{{ 'plans.work.save_impact.unrecorded' | translate }}</dt>
            <dd>{{ impact.planStats.unrecordedCount }}</dd>
          </div>
          <div>
            <dt>{{ 'plans.work.save_impact.average_delta' | translate }}</dt>
            <dd>{{ averageDeltaLabel(impact.planStats.averageDeltaDays) }}</dd>
          </div>
        </dl>
        @if (impact.workbenchFieldCultivationId != null) {
          <a
            class="work-record-save-impact__workbench-link"
            [routerLink]="['/plans', planId]"
            [queryParams]="{ field_cultivation_id: impact.workbenchFieldCultivationId }"
          >
            {{ 'plans.work.save_impact.workbench_link' | translate }}
          </a>
        }
        <a class="work-record-save-impact__learn-link" [routerLink]="['/plans', planId, 'learn']">
          {{ 'plans.work.save_impact.learn_link' | translate }}
        </a>
      }
    </section>
  `,
  styleUrls: ['./work-record-save-impact-panel.component.css']
})
export class WorkRecordSaveImpactPanelComponent {
  @Input({ required: true }) planId!: number;
  @Input() impact: WorkRecordSaveImpactViewModel | null = null;
  @Input() loading = false;
  @Input() error: string | null = null;
  @Output() dismiss = new EventEmitter<void>();

  averageDeltaLabel(average: number | null): string {
    if (average == null) {
      return '—';
    }
    return formatPlanTaskScheduleAverageDeltaDaysLabel(average);
  }
}
