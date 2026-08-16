import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { LearnPostMasterPayload } from '../../domain/plans/learn-proposal-application-progress';
import { buildPlanDetailAdjustNavigation } from '../../domain/plans/learn-master-update-orchestration';

@Component({
  selector: 'app-plan-learn-post-master-confirmation',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    @if (payload) {
      <section
        class="learn-post-master"
        aria-labelledby="learn-post-master-heading"
        role="status"
      >
        <h3 id="learn-post-master-heading" class="learn-post-master__title">
          {{ 'plans.learn.post_master.title' | translate }}
        </h3>
        <p class="learn-post-master__lead">
          {{ 'plans.learn.post_master.lead' | translate }}
        </p>
        <dl class="learn-post-master__details">
          <div class="learn-post-master__detail-row">
            <dt>{{ 'plans.learn.post_master.crop_label' | translate }}</dt>
            <dd>{{ payload.cropName }}</dd>
          </div>
          @if (payload.kind === 'stage_gdd') {
            <div class="learn-post-master__detail-row">
              <dt>{{ 'plans.learn.post_master.stage_label' | translate }}</dt>
              <dd>{{ payload.stageName }}</dd>
            </div>
            <div class="learn-post-master__detail-row">
              <dt>{{ 'plans.learn.post_master.required_gdd_label' | translate }}</dt>
              <dd>{{ formatRequiredGdd(payload.appliedRequiredGdd) }}</dd>
            </div>
          } @else if (payload.kind === 'bp_amount') {
            <div class="learn-post-master__detail-row">
              <dt>{{ 'plans.learn.post_master.category_label' | translate }}</dt>
              <dd>{{ categoryLabel(payload.category, payload.kind) | translate }}</dd>
            </div>
            <div class="learn-post-master__detail-row">
              <dt>{{ 'plans.learn.post_master.task_type_label' | translate }}</dt>
              <dd>{{ taskTypeLabel(payload.taskType) | translate }}</dd>
            </div>
          } @else {
            <div class="learn-post-master__detail-row">
              <dt>{{ 'plans.learn.post_master.category_label' | translate }}</dt>
              <dd>{{ categoryLabel(payload.category, payload.kind) | translate }}</dd>
            </div>
          }
        </dl>
        <a
          class="btn-primary learn-post-master__cta"
          [routerLink]="workbenchLink.commands"
          [queryParams]="workbenchLink.queryParams"
        >
          {{ 'plans.learn.post_master.open_workbench' | translate }}
        </a>
      </section>
    }
  `,
  styleUrls: ['./plan-learn-post-master-confirmation.component.css']
})
export class PlanLearnPostMasterConfirmationComponent {
  @Input({ required: true }) planId!: number;
  @Input() payload: LearnPostMasterPayload | null = null;

  get workbenchLink(): ReturnType<typeof buildPlanDetailAdjustNavigation> {
    return buildPlanDetailAdjustNavigation(this.planId);
  }

  formatRequiredGdd(value: number | null | undefined): string {
    return value == null ? '—' : String(value);
  }

  categoryLabel(category: string | undefined, kind: LearnPostMasterPayload['kind']): string {
    if (kind === 'bp_amount') {
      return `plans.learn.bp_amount_adjustment.category.${category ?? 'general'}`;
    }
    return `plans.learn.bp_timing_adjustment.category.${category ?? 'general'}`;
  }

  taskTypeLabel(taskType: string | undefined): string {
    return `plans.learn.bp_amount_adjustment.task_type.${taskType ?? 'field_work'}`;
  }
}
