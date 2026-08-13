import { CommonModule } from '@angular/common';
import { Component, Input } from '@angular/core';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-plan-reoptimization-banner',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  template: `
    @if (visible) {
      <div class="plan-reoptimization-banner" role="status" aria-live="polite">
        <p class="plan-reoptimization-banner__message">
          {{ 'plans.show.reoptimization_banner.message' | translate }}
        </p>
        <p class="plan-reoptimization-banner__hint">
          {{ 'plans.show.reoptimization_banner.hint' | translate }}
        </p>
      </div>
    }
  `,
  styleUrls: ['./plan-reoptimization-banner.component.css']
})
export class PlanReoptimizationBannerComponent {
  @Input() visible = false;
}
