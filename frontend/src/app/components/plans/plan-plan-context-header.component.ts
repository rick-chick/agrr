import { Component, Input } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';
import { PlanDisplayNamePipe } from '../../core/plan-display-name.pipe';
import { PlanDetailContextNavComponent } from './plan-detail-context-nav.component';

@Component({
  selector: 'app-plan-plan-context-header',
  standalone: true,
  imports: [TranslateModule, PlanDisplayNamePipe, PlanDetailContextNavComponent],
  template: `
    <header class="page-header page-header--compact plan-context-header">
      @if (planName) {
        <h1 id="plan-context-page-title" class="visually-hidden">{{
          pageTitleKey | translate: { name: (planName | planDisplayName) }
        }}</h1>
        <p class="plan-context-header__identity">
          <span class="plan-context-header__plan-name">{{ planName | planDisplayName }}</span>
        </p>
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
