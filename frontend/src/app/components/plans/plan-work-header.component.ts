import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PlanDisplayNamePipe } from '../../core/plan-display-name.pipe';
import { PlanWorkContextNavComponent } from './plan-work-context-nav.component';

@Component({
  selector: 'app-plan-work-header',
  standalone: true,
  imports: [RouterLink, TranslateModule, PlanDisplayNamePipe, PlanWorkContextNavComponent],
  template: `
    <header class="page-header page-header--compact plan-context-header">
      <div class="plan-context-header__crumbs">
        <a class="plan-context-header__back" [routerLink]="['/work']">{{
          'plans.work.back_to_hub' | translate
        }}</a>
        @if (planName) {
          <a class="plan-context-header__forward" [routerLink]="['/plans', planId]">{{
            'plans.work.back_to_plan' | translate
          }}</a>
        }
      </div>
      @if (planName) {
        <h1 id="plan-work-page-title" class="visually-hidden">{{
          'plans.work.page_title' | translate: { name: (planName | planDisplayName) }
        }}</h1>
        <p class="plan-context-header__identity">
          <span class="plan-context-header__plan-name">{{ planName | planDisplayName }}</span>
        </p>
        <app-plan-work-context-nav [planId]="planId" />
      }
    </header>
  `,
  styleUrls: ['./plan-context-header.css']
})
export class PlanWorkHeaderComponent {
  @Input({ required: true }) planId!: number;
  @Input() planName: string | null = null;
}
