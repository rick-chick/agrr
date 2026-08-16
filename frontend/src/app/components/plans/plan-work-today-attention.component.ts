import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { PlanWorkTodayAttentionSummary } from '../../domain/plans/build-plan-work-today-attention';

@Component({
  selector: 'app-plan-work-today-attention',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    @if (loading) {
      <section
        class="plan-work-today-attention"
        role="status"
        aria-labelledby="plan-work-today-attention-title"
      >
        <h2 id="plan-work-today-attention-title" class="plan-work-today-attention__title">
          {{ 'plans.work.today_attention.title' | translate }}
        </h2>
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      </section>
    } @else if (error) {
      <section
        class="plan-work-today-attention"
        role="status"
        aria-labelledby="plan-work-today-attention-title"
      >
        <h2 id="plan-work-today-attention-title" class="plan-work-today-attention__title">
          {{ 'plans.work.today_attention.title' | translate }}
        </h2>
        <div class="page-alert-error" role="alert">
          <p>{{ error | translate }}</p>
        </div>
      </section>
    } @else if (summary?.hasAnyAttention) {
      <section
        class="plan-work-today-attention"
        role="status"
        aria-labelledby="plan-work-today-attention-title"
      >
        <h2 id="plan-work-today-attention-title" class="plan-work-today-attention__title">
          {{ 'plans.work.today_attention.title' | translate }}
        </h2>

        @if (summary!.weatherTriggers.length) {
          <ul class="plan-work-today-attention__weather-list">
            @for (trigger of summary!.weatherTriggers; track trigger.proposalId) {
              <li class="plan-work-today-attention__weather-item">
                <p class="plan-work-today-attention__weather-type">
                  {{
                    'plans.work.today_attention.weather_trigger.' + trigger.triggerType
                      | translate
                  }}
                </p>
                <p class="plan-work-today-attention__weather-target">
                  {{
                    'plans.work.today_attention.weather_target'
                      | translate: { field: trigger.fieldName, crop: trigger.cropName }
                  }}
                </p>
                <p class="plan-work-today-attention__weather-rationale">
                  {{ trigger.rationaleI18nKey | translate: trigger.rationaleI18nParams }}
                </p>
                <a
                  class="plan-work-today-attention__proposal-link"
                  [routerLink]="['/plans', planId]"
                  [queryParams]="{ weatherProposal: trigger.proposalId }"
                >
                  {{ 'plans.work.today_attention.weather_proposal_cta' | translate }}
                </a>
              </li>
            }
          </ul>
        }

        <dl class="plan-work-today-attention__grid">
          <div>
            <dt>{{ 'plans.work.today_attention.frost_risk' | translate }}</dt>
            <dd>{{ summary!.frostRiskCount }}</dd>
          </div>
          <div>
            <dt>{{ 'plans.work.today_attention.gdd_delay' | translate }}</dt>
            <dd>{{ summary!.gddDelayCount }}</dd>
          </div>
          <div>
            <dt>{{ 'plans.work.today_attention.threshold_exceeded' | translate }}</dt>
            <dd>{{ summary!.thresholdExceededCount }}</dd>
          </div>
        </dl>

        @if (summary!.frostRiskFields.length) {
          <ul class="plan-work-today-attention__list">
            @for (field of summary!.frostRiskFields; track field.fieldCultivationId) {
              <li>
                {{
                  'plans.work.today_attention.frost_risk_field'
                    | translate
                      : {
                          field: field.fieldName,
                          crop: field.cropName
                        }
                }}
              </li>
            }
          </ul>
        }

        @if (summary!.gddDelayTasks.length) {
          <ul class="plan-work-today-attention__list">
            @for (task of summary!.gddDelayTasks; track task.itemId) {
              <li>
                {{
                  'plans.work.today_attention.gdd_delay_task'
                    | translate: { name: task.name }
                }}
              </li>
            }
          </ul>
        }

        @if (summary!.thresholdExceededTasks.length) {
          <ul class="plan-work-today-attention__list">
            @for (task of summary!.thresholdExceededTasks; track task.itemId) {
              <li>
                {{
                  'plans.work.today_attention.threshold_exceeded_task'
                    | translate: { name: task.name }
                }}
              </li>
            }
          </ul>
        }

        <a
          class="plan-work-today-attention__learn-link"
          [routerLink]="['/plans', planId, 'learn']"
        >
          {{ 'plans.work.today_attention.learn_cta' | translate }}
        </a>
      </section>
    }
  `,
  styleUrls: ['./plan-work-today-attention.component.css']
})
export class PlanWorkTodayAttentionComponent {
  @Input({ required: true }) planId!: number;
  @Input() summary: PlanWorkTodayAttentionSummary | null = null;
  @Input() loading = false;
  @Input() error: string | null = null;
}
