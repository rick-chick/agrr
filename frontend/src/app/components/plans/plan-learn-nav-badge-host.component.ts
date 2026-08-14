import { Component, Input, OnChanges, OnDestroy, OnInit, SimpleChanges, inject } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { PLAN_LEARN_PROVIDERS } from '../../usecase/plans/plan-learn.providers';
import type { LearnLoopPhaseId } from '../../domain/plans/learn-loop-phase';
import {
  learnNavBadgeAriaLabelKey,
  learnNavBadgeAriaParams,
  learnNavBadgePhaseLabelKey,
  type LearnNavBadge
} from '../../domain/plans/learn-loop-cross-display';
import {
  PlanLearnLoopSummaryCoordinator,
  type PlanLearnLoopSummarySnapshot
} from '../../usecase/plans/plan-learn-loop-summary.coordinator';

@Component({
  selector: 'app-plan-learn-nav-badge-host',
  standalone: true,
  imports: [TranslateModule],
  providers: [...PLAN_LEARN_PROVIDERS, PlanLearnLoopSummaryCoordinator],
  template: `
    @if (snapshot?.badge; as badge) {
      <span
        class="plan-context-nav__learn-badge"
        [attr.aria-label]="badgeAriaLabel(badge) | translate: badgeAriaParams(badge)"
      >
        @if (badge.kind === 'count') {
          {{ badge.count }}
        } @else {
          {{ phaseLabelKey(badge.phase) | translate }}
        }
      </span>
    }
  `,
})
export class PlanLearnNavBadgeHostComponent implements OnInit, OnChanges, OnDestroy {
  @Input({ required: true }) planId!: number;

  private readonly coordinator = inject(PlanLearnLoopSummaryCoordinator);
  private unsubscribe: (() => void) | null = null;

  snapshot: PlanLearnLoopSummarySnapshot | null = null;

  ngOnInit(): void {
    this.unsubscribe = this.coordinator.subscribe((snapshot) => {
      this.snapshot = snapshot;
    });
    this.coordinator.load(this.planId);
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['planId'] && !changes['planId'].firstChange) {
      this.coordinator.load(this.planId);
    }
  }

  ngOnDestroy(): void {
    this.unsubscribe?.();
  }

  phaseLabelKey(phase: LearnLoopPhaseId): string {
    return learnNavBadgePhaseLabelKey(phase);
  }

  badgeAriaLabel(badge: LearnNavBadge): string {
    return learnNavBadgeAriaLabelKey(badge);
  }

  badgeAriaParams(badge: LearnNavBadge): Record<string, string | number> {
    if (badge.kind === 'phase') {
      return learnNavBadgeAriaParams(badge, learnNavBadgePhaseLabelKey(badge.phase));
    }
    return learnNavBadgeAriaParams(badge);
  }
}
