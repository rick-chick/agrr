import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PlanLearnLoopProgressStripComponent } from './plan-learn-loop-progress-strip.component';

@Component({
  selector: 'app-plan-reoptimization-banner',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule, PlanLearnLoopProgressStripComponent],
  template: `
    @if (visible) {
      <div class="plan-reoptimization-banner" role="status" aria-live="polite">
        <p class="plan-reoptimization-banner__message">
          {{ 'plans.show.reoptimization_banner.message' | translate }}
        </p>
        <p class="plan-reoptimization-banner__hint">
          {{ 'plans.show.reoptimization_banner.hint' | translate }}
        </p>
        <app-plan-learn-loop-progress-strip [planId]="planId" />
        <a
          class="btn btn-primary plan-reoptimization-banner__learn-link"
          [routerLink]="learnLink"
        >
          {{ 'plans.task_schedules.orchestration.return_to_learn' | translate }}
        </a>
      </div>
    }
  `,
  styleUrls: ['./plan-reoptimization-banner.component.css']
})
export class PlanReoptimizationBannerComponent {
  @Input() visible = false;
  @Input({ required: true }) planId!: number;

  get learnLink(): (string | number)[] {
    return ['/plans', this.planId, 'learn'];
  }
}
