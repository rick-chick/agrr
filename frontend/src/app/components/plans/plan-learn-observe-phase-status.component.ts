import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import type { LearnObservePhaseStatus } from '../../domain/plans/resolve-learn-observe-phase-status';

@Component({
  selector: 'app-plan-learn-observe-phase-status',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    @if (status) {
      <div class="plan-learn-observe-phase" role="status" aria-live="polite">
        @if (status === 'unrecorded') {
          <p>
            {{
              'plans.learn.observe_phase.unrecorded_message'
                | translate: { count: unrecordedCount }
            }}
          </p>
          <a class="plan-learn-observe-phase__cta" [routerLink]="['/plans', planId, 'work']">
            {{ 'plans.learn.observe_phase.unrecorded_cta' | translate }}
          </a>
        } @else {
          <p>{{ 'plans.learn.observe_phase.complete_message' | translate }}</p>
        }
      </div>
    }
  `,
  styleUrls: ['./plan-learn-observe-phase-status.component.css']
})
export class PlanLearnObservePhaseStatusComponent {
  @Input({ required: true }) planId!: number;
  @Input() status: LearnObservePhaseStatus | null = null;
  @Input() unrecordedCount = 0;
}
