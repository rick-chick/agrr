import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { PlanWorkTodayAttention } from '../../domain/plans/build-plan-work-today-attention';
import { hasPlanWorkTodayAttention } from '../../domain/plans/build-plan-work-today-attention';

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
      <section class="plan-work-today-attention" role="alert">
        <h2 class="plan-work-today-attention__title">
          {{ 'plans.work.today_attention.title' | translate }}
        </h2>
        <div class="page-alert-error">
          <p>{{ error | translate }}</p>
        </div>
      </section>
    } @else if (hasAlerts) {
      <section
        class="plan-work-today-attention"
        role="status"
        aria-labelledby="plan-work-today-attention-title"
      >
        <h2 id="plan-work-today-attention-title" class="plan-work-today-attention__title">
          {{ 'plans.work.today_attention.title' | translate }}
        </h2>

        <dl class="plan-work-today-attention__grid">
          @if (attention!.frostRiskCount > 0) {
            <div>
              <dt>{{ 'plans.work.today_attention.frost_risk' | translate }}</dt>
              <dd>{{ attention!.frostRiskCount }}</dd>
            </div>
          }
          @if (attention!.thresholdExceededCount > 0) {
            <div>
              <dt>{{ 'plans.work.today_attention.threshold_exceeded' | translate }}</dt>
              <dd>{{ attention!.thresholdExceededCount }}</dd>
            </div>
          }
          @if (attention!.gddDelayCount > 0) {
            <div>
              <dt>{{ 'plans.work.today_attention.gdd_delay' | translate }}</dt>
              <dd>{{ attention!.gddDelayCount }}</dd>
            </div>
          }
        </dl>

        <a
          class="plan-work-today-attention__learn-link"
          [routerLink]="['/plans', planId, 'learn']"
        >
          {{ 'plans.work.today_attention.learn_cta' | translate }}
        </a>
      </section>
    } @else if (showEmptyState) {
      <section
        class="plan-work-today-attention plan-work-today-attention--empty"
        role="status"
        aria-labelledby="plan-work-today-attention-title"
      >
        <h2 id="plan-work-today-attention-title" class="plan-work-today-attention__title">
          {{ 'plans.work.today_attention.title' | translate }}
        </h2>
        <p class="plan-work-today-attention__empty">
          {{ 'plans.work.today_attention.empty' | translate }}
        </p>
      </section>
    }
  `,
  styleUrls: ['./plan-work-today-attention.component.css']
})
export class PlanWorkTodayAttentionComponent {
  @Input({ required: true }) planId!: number;
  @Input() attention: PlanWorkTodayAttention | null = null;
  @Input() loading = false;
  @Input() error: string | null = null;
  @Input() showEmptyState = false;

  get hasAlerts(): boolean {
    return hasPlanWorkTodayAttention(this.attention);
  }
}
