import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-entry-schedule-wizard-progress',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  styleUrls: ['../public-plans/public-plan.component.css'],
  host: {
    wizardProgress: ''
  },
  template: `
    <div class="compact-progress">
      <div
        class="compact-step"
        [class.active]="activeStep === 'farm'"
        [class.completed]="activeStep === 'crop'"
      >
        <div class="step-number">1</div>
        @if (activeStep === 'crop') {
          <a routerLink="/entry-schedule" class="step-label step-label-link">{{
            'entrySchedule.steps.farm' | translate
          }}</a>
        } @else {
          <span class="step-label">{{ 'entrySchedule.steps.farm' | translate }}</span>
        }
      </div>
      <div class="compact-step-divider" [class.completed]="activeStep === 'crop'"></div>
      <div class="compact-step" [class.active]="activeStep === 'crop'">
        <div class="step-number">2</div>
        <span class="step-label">{{ 'entrySchedule.steps.crop' | translate }}</span>
      </div>
    </div>
  `
})
export class EntryScheduleWizardProgressComponent {
  @Input({ required: true }) activeStep!: 'farm' | 'crop';
}
