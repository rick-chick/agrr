import { Component, EventEmitter, Input, Output } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-plan-post-save-onboarding-banner',
  standalone: true,
  imports: [CommonModule, RouterLink, TranslateModule],
  template: `
    <div class="plan-post-save-onboarding-banner" role="status" aria-live="polite">
      <div class="plan-post-save-onboarding-banner__content">
        <p class="plan-post-save-onboarding-banner__message">
          {{ 'plans.show.post_save_onboarding.message' | translate }}
        </p>
        <p class="plan-post-save-onboarding-banner__hint">
          {{ 'plans.show.post_save_onboarding.hint' | translate }}
        </p>
        <div class="plan-post-save-onboarding-banner__actions">
          <a
            class="btn btn-secondary plan-post-save-onboarding-banner__link"
            [routerLink]="['/plans', planId, 'task_schedule']"
          >
            {{ 'plans.show.post_save_onboarding.task_schedule_link' | translate }}
          </a>
          <a
            class="btn btn-primary plan-post-save-onboarding-banner__link"
            [routerLink]="['/plans', planId, 'work']"
          >
            {{ 'plans.show.post_save_onboarding.work_link' | translate }}
          </a>
        </div>
      </div>
      <button
        type="button"
        class="btn-link plan-post-save-onboarding-banner__dismiss"
        (click)="dismiss.emit()"
        [attr.aria-label]="'plans.show.post_save_onboarding.dismiss' | translate"
      >
        {{ 'plans.show.post_save_onboarding.dismiss' | translate }}
      </button>
    </div>
  `,
  styleUrls: ['./plan-post-save-onboarding-banner.component.css']
})
export class PlanPostSaveOnboardingBannerComponent {
  @Input({ required: true }) planId!: number;
  @Output() dismiss = new EventEmitter<void>();
}
