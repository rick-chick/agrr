import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PlanDisplayNamePipe } from '../../core/plan-display-name.pipe';
import { PlanDetailContextNavComponent } from './plan-detail-context-nav.component';

@Component({
  selector: 'app-plan-plan-context-header',
  standalone: true,
  imports: [RouterLink, TranslateModule, PlanDisplayNamePipe, PlanDetailContextNavComponent],
  template: `
    <header class="page-header page-header--compact plan-context-header">
      @if (planName) {
        <h1 id="plan-context-page-title" class="visually-hidden">{{
          pageTitleKey | translate: { name: (planName | planDisplayName) }
        }}</h1>
        <nav class="plan-context-header__nav" aria-label="Breadcrumb">
          <ol class="plan-context-header__crumbs">
            <li class="plan-context-header__crumb">
              <a routerLink="/plans" class="plan-context-header__back">
                {{ 'plans.index.title' | translate }}
              </a>
            </li>
            <li class="plan-context-header__crumb">
              <span class="plan-context-header__current" aria-current="page">{{
                planName | planDisplayName
              }}</span>
            </li>
          </ol>
        </nav>
        <app-plan-detail-context-nav [planId]="planId" />
      }
    </header>
  `,
  styleUrls: ['./plan-context-header.css']
})
export class PlanPlanContextHeaderComponent {
  @Input({ required: true }) planId!: number;
  @Input() planName: string | null = null;
  @Input({ required: true }) pageTitleKey!: string;
}
