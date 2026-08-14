import { Component, Input } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PLAN_LEARN_PROVIDERS } from '../../usecase/plans/plan-learn.providers';
import { PlanLearnLoopSummaryCoordinator } from '../../usecase/plans/plan-learn-loop-summary.coordinator';
import { PlanLearnNavBadgeHostComponent } from './plan-learn-nav-badge-host.component';

@Component({
  selector: 'app-plan-detail-context-nav',
  standalone: true,
  imports: [RouterLink, RouterLinkActive, TranslateModule, PlanLearnNavBadgeHostComponent],
  providers: [...PLAN_LEARN_PROVIDERS, PlanLearnLoopSummaryCoordinator],
  template: `
    <nav
      class="plan-context-nav plan-context-nav--spaced"
      role="navigation"
      [attr.aria-label]="'plans.show.nav.aria_label' | translate"
    >
      <a
        [routerLink]="['/plans', planId]"
        routerLinkActive="plan-context-nav__link--active"
        [routerLinkActiveOptions]="{ exact: true }"
        class="plan-context-nav__link"
      >{{ 'plans.show.nav.workbench' | translate }}</a>
      <a
        [routerLink]="['/plans', planId, 'task_schedule']"
        routerLinkActive="plan-context-nav__link--active"
        class="plan-context-nav__link"
      >{{ 'plans.show.nav.task_schedule' | translate }}</a>
      <a
        [routerLink]="['/plans', planId, 'work']"
        routerLinkActive="plan-context-nav__link--active"
        [routerLinkActiveOptions]="{ exact: true }"
        class="plan-context-nav__link plan-context-nav__link--with-badge"
      >
        {{ 'plans.work.nav.work' | translate }}
        <app-plan-learn-nav-badge-host [planId]="planId" />
      </a>
      <a
        [routerLink]="['/plans', planId, 'work_records']"
        routerLinkActive="plan-context-nav__link--active"
        class="plan-context-nav__link"
      >{{ 'plans.work.nav.history' | translate }}</a>
      <a
        [routerLink]="['/plans', planId, 'learn']"
        routerLinkActive="plan-context-nav__link--active"
        class="plan-context-nav__link plan-context-nav__link--with-badge"
      >
        {{ 'plans.show.nav.learn' | translate }}
        <app-plan-learn-nav-badge-host [planId]="planId" />
      </a>
    </nav>
  `,
  styleUrls: ['./plan-context-nav.css']
})
export class PlanDetailContextNavComponent {
  @Input({ required: true }) planId!: number;
}
