import { Component, DestroyRef, Input, OnInit, inject } from '@angular/core';
import { takeUntilDestroyed } from '@angular/core/rxjs-interop';
import { TranslateModule } from '@ngx-translate/core';
import { forkJoin, of } from 'rxjs';
import { catchError } from 'rxjs/operators';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import {
  resolveLearnLoopNavBadge,
  type LearnLoopNavBadge
} from '../../domain/plans/learn-loop-nav-badge';
import { hydrateLearnOrchestrationProgress } from '../../domain/plans/learn-master-update-orchestration';
import { hydrateLearnProposalApplicationProgress } from '../../domain/plans/learn-proposal-application-progress';
import { PLAN_GATEWAY, PlanGateway } from '../../usecase/plans/plan-gateway';

@Component({
  selector: 'app-plan-learn-nav-badge',
  standalone: true,
  imports: [TranslateModule],
  providers: [{ provide: PLAN_GATEWAY, useClass: PlanApiGateway }],
  template: `
    @if (badge) {
      @if (badge.kind === 'proposal_count') {
        <span
          class="plan-context-nav__badge plan-context-nav__badge--count"
          [attr.aria-label]="
            'plans.show.nav.learn_badge.proposals' | translate: { count: badge.count }
          "
        >
          {{ badge.count }}
        </span>
      } @else if (badge.phaseId) {
        <span
          class="plan-context-nav__badge plan-context-nav__badge--phase"
          [attr.aria-label]="
            'plans.show.nav.learn_badge.phase' | translate: { phase: phaseLabelKey | translate }
          "
        >
          {{ phaseLabelKey | translate }}
        </span>
      }
    }
  `,
  styleUrls: ['./plan-learn-nav-badge.component.css']
})
export class PlanLearnNavBadgeComponent implements OnInit {
  @Input({ required: true }) planId!: number;

  badge: LearnLoopNavBadge | null = null;

  private readonly gateway = inject<PlanGateway>(PLAN_GATEWAY);
  private readonly destroyRef = inject(DestroyRef);

  get phaseLabelKey(): string {
    if (!this.badge?.phaseId) {
      return '';
    }
    return `plans.learn.loop.phase.${this.badge.phaseId}`;
  }

  ngOnInit(): void {
    forkJoin({
      varianceSummary: this.gateway.getPlanVsActualSummary(this.planId),
      learningSnapshot: this.gateway.getVarianceLearning(this.planId).pipe(catchError(() => of(null)))
    })
      .pipe(takeUntilDestroyed(this.destroyRef))
      .subscribe({
        next: ({ varianceSummary, learningSnapshot }) => {
          if (learningSnapshot?.proposal_application_progress) {
            hydrateLearnProposalApplicationProgress(
              this.planId,
              learningSnapshot.proposal_application_progress
            );
          }
          if (learningSnapshot?.reorganize_orchestration_progress) {
            hydrateLearnOrchestrationProgress(
              this.planId,
              learningSnapshot.reorganize_orchestration_progress
            );
          }
          this.badge = resolveLearnLoopNavBadge({
            planId: this.planId,
            varianceSummary,
            learningSnapshot
          });
        },
        error: () => {
          this.badge = null;
        }
      });
  }
}
