import { Component, Input } from '@angular/core';
import { RouterLink, RouterLinkActive } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-plan-work-nav',
  standalone: true,
  imports: [RouterLink, RouterLinkActive, TranslateModule],
  template: `
    <nav class="plan-work-nav" aria-label="Work navigation">
      <a
        [routerLink]="['/plans', planId, 'work']"
        routerLinkActive="plan-work-nav__link--active"
        class="plan-work-nav__link"
      >{{ 'plans.work.nav.work' | translate }}</a>
      <a
        [routerLink]="['/plans', planId, 'task_schedule']"
        routerLinkActive="plan-work-nav__link--active"
        class="plan-work-nav__link"
      >{{ 'plans.work.nav.schedule' | translate }}</a>
      <a
        [routerLink]="['/plans', planId, 'work_records']"
        routerLinkActive="plan-work-nav__link--active"
        class="plan-work-nav__link"
      >{{ 'plans.work.nav.history' | translate }}</a>
    </nav>
  `,
  styleUrls: ['./plan-work-nav.component.css']
})
export class PlanWorkNavComponent {
  @Input({ required: true }) planId!: number;
}
