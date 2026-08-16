import { Component, EventEmitter, Input, Output } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-plan-post-save-banner',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    @if (visible) {
      <section
        class="plan-post-save-banner"
        role="region"
        aria-labelledby="plan-post-save-banner-title"
      >
        <div class="plan-post-save-banner__header">
          <h2 id="plan-post-save-banner-title" class="plan-post-save-banner__title">
            {{ 'plans.show.post_save_banner.title' | translate }}
          </h2>
          <button
            type="button"
            class="plan-post-save-banner__dismiss"
            (click)="dismiss.emit()"
            [attr.aria-label]="'plans.show.post_save_banner.dismiss' | translate"
          >
            {{ 'plans.show.post_save_banner.dismiss' | translate }}
          </button>
        </div>
        <p class="plan-post-save-banner__message">
          {{ 'plans.show.post_save_banner.message' | translate }}
        </p>
        <p class="plan-post-save-banner__hint">
          {{ 'plans.show.post_save_banner.hint' | translate }}
        </p>
        <div class="plan-post-save-banner__actions">
          <a class="btn btn-primary" [routerLink]="taskScheduleLink">
            {{ 'plans.show.post_save_banner.task_schedule_link' | translate }}
          </a>
          <a class="btn btn-secondary" [routerLink]="workLink">
            {{ 'plans.show.post_save_banner.work_link' | translate }}
          </a>
        </div>
      </section>
    }
  `,
  styleUrls: ['./plan-post-save-banner.component.css']
})
export class PlanPostSaveBannerComponent {
  @Input({ required: true }) planId!: number;
  @Input() visible = false;
  @Output() dismiss = new EventEmitter<void>();

  get taskScheduleLink(): (string | number)[] {
    return ['/plans', this.planId, 'task_schedule'];
  }

  get workLink(): (string | number)[] {
    return ['/plans', this.planId, 'work'];
  }
}
