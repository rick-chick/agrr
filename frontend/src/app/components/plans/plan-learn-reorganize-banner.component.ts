import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';
import { PlanLearnLoopProgressStripComponent } from './plan-learn-loop-progress-strip.component';

export type PlanLearnReorganizeBannerContext = 'placement' | 'optimizing';

@Component({
  selector: 'app-plan-learn-reorganize-banner',
  standalone: true,
  imports: [RouterLink, TranslateModule, PlanLearnLoopProgressStripComponent],
  template: `
    @if (visible) {
      <div class="learn-reorganize-banner" role="status" aria-live="polite">
        <p class="learn-reorganize-banner__message">
          {{ messageKey | translate }}
        </p>
        <p class="learn-reorganize-banner__hint">
          {{ hintKey | translate }}
        </p>
        <app-plan-learn-loop-progress-strip [planId]="planId" />
        <a class="btn-primary learn-reorganize-banner__learn-link" [routerLink]="learnLink">
          {{ 'plans.learn.reorganize.return_to_learn' | translate }}
        </a>
      </div>
    }
  `,
  styleUrls: ['./plan-learn-reorganize-banner.component.css']
})
export class PlanLearnReorganizeBannerComponent {
  @Input({ required: true }) planId!: number;
  @Input() visible = false;
  @Input() context: PlanLearnReorganizeBannerContext = 'placement';

  get messageKey(): string {
    return `plans.learn.reorganize.${this.context}.message`;
  }

  get hintKey(): string {
    return `plans.learn.reorganize.${this.context}.hint`;
  }

  get learnLink(): (string | number)[] {
    return ['/plans', this.planId, 'learn'];
  }
}
