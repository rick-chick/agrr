import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

@Component({
  selector: 'app-wizard-progress-pattern',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  template: `
    <div class="compact-progress" data-testid="wizard-progress">
      <div
        class="compact-step"
        [class.active]="activeStep === 1"
        [class.completed]="activeStep === 2"
      >
        <div class="step-number">1</div>
        @if (activeStep === 2 && step1Link) {
          <a [routerLink]="step1Link" class="step-label step-label-link">{{
            step1LabelKey | translate
          }}</a>
        } @else {
          <span class="step-label">{{ step1LabelKey | translate }}</span>
        }
      </div>
      <div class="compact-step-divider" [class.completed]="activeStep === 2"></div>
      <div class="compact-step" [class.active]="activeStep === 2">
        <div class="step-number">2</div>
        <span class="step-label">{{ step2LabelKey | translate }}</span>
      </div>
    </div>
  `,
  styleUrls: ['./wizard-progress.pattern.css'],
})
export class WizardProgressPattern {
  @Input({ required: true }) activeStep!: 1 | 2;
  @Input({ required: true }) step1LabelKey!: string;
  @Input({ required: true }) step2LabelKey!: string;
  @Input() step1Link?: string | string[];
}
