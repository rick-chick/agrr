import { Component, Input } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-plan-detail-context-nav',
  standalone: true,
  imports: [RouterLink, RouterLinkActive, TranslateModule],
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
        class="plan-context-nav__link"
      >{{ 'plans.work.nav.work' | translate }}</a>
      <a
        [routerLink]="['/plans', planId, 'work_records']"
        routerLinkActive="plan-context-nav__link--active"
        class="plan-context-nav__link"
      >{{ 'plans.work.nav.history' | translate }}</a>
    </nav>
  `,
  styleUrls: ['./plan-context-nav.css']
})
export class PlanDetailContextNavComponent {
  @Input({ required: true }) planId!: number;
}
