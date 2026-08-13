import { Component, Input } from '@angular/core';
import { CommonModule } from '@angular/common';
import { Router } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { BlueprintTimingAdjustmentProposal } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import { blueprintTimingPrefillStorageKey, blueprintTimingLearnApplyContextStorageKey } from '../../domain/plans/blueprint-timing-adjustment-proposal';
import { formatPlanTaskScheduleAverageDeltaDaysLabel } from '../../domain/work-schedule/format-plan-task-schedule-delta-days';
import { cropPlanWizardQueryParams } from '../../domain/crops/plan-wizard-context';

@Component({
  selector: 'app-blueprint-timing-adjustment-proposals-view',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    <section
      class="task-schedule-variance__section blueprint-timing-adjustment"
      aria-labelledby="blueprint-timing-adjustment-heading"
    >
      <h3 id="blueprint-timing-adjustment-heading" class="task-schedule-variance__section-title">
        {{ 'plans.learn.bp_timing_adjustment.title' | translate }}
      </h3>
      <p class="blueprint-timing-adjustment__lead">
        {{ 'plans.learn.bp_timing_adjustment.lead' | translate }}
      </p>

      @if (loading) {
        <p class="master-loading">{{ 'common.loading' | translate }}</p>
      } @else if (proposals.length === 0) {
        <p class="blueprint-timing-adjustment__empty">
          {{ 'plans.learn.bp_timing_adjustment.empty' | translate }}
        </p>
      } @else {
        <ul class="blueprint-timing-adjustment__list">
          @for (proposal of proposals; track proposalKey(proposal)) {
            <li class="blueprint-timing-adjustment__item">
              <div class="blueprint-timing-adjustment__summary">
                <p class="blueprint-timing-adjustment__name">
                  {{ proposal.cropName }} — {{ categoryLabel(proposal.category) | translate }}
                </p>
                <p class="blueprint-timing-adjustment__delta">
                  {{
                    'plans.learn.bp_timing_adjustment.delta_label'
                      | translate: { delta: deltaLabel(proposal.averageDeltaDays) }
                  }}
                </p>
                <p class="blueprint-timing-adjustment__meta">
                  {{
                    'plans.learn.bp_timing_adjustment.affected_count'
                      | translate: { count: proposal.affectedBlueprintCount }
                  }}
                </p>
              </div>
              <button
                type="button"
                class="btn-secondary blueprint-timing-adjustment__cta"
                (click)="openSetupProposal(proposal)"
              >
                {{ 'plans.learn.bp_timing_adjustment.cta' | translate }}
              </button>
            </li>
          }
        </ul>
      }
    </section>
  `,
  styleUrls: ['./blueprint-timing-adjustment-proposals-view.component.css']
})
export class BlueprintTimingAdjustmentProposalsViewComponent {
  @Input({ required: true }) planId!: number;
  @Input() loading = false;
  @Input() proposals: BlueprintTimingAdjustmentProposal[] = [];

  constructor(private readonly router: Router) {}

  proposalKey(proposal: BlueprintTimingAdjustmentProposal): string {
    return `${proposal.cropId}-${proposal.category}`;
  }

  categoryLabel(category: string): string {
    return `plans.learn.bp_timing_adjustment.category.${category}`;
  }

  deltaLabel(deltaDays: number): string {
    return formatPlanTaskScheduleAverageDeltaDaysLabel(deltaDays);
  }

  openSetupProposal(proposal: BlueprintTimingAdjustmentProposal): void {
    sessionStorage.setItem(
      blueprintTimingPrefillStorageKey(proposal.cropId),
      JSON.stringify(proposal.proposalBody)
    );
    sessionStorage.setItem(
      blueprintTimingLearnApplyContextStorageKey(this.planId, proposal.cropId),
      JSON.stringify({ cropName: proposal.cropName, category: proposal.category })
    );
    void this.router.navigate(['/crops', proposal.cropId, 'setup_proposal'], {
      queryParams: cropPlanWizardQueryParams(this.planId, 'learn')
    });
  }
}
