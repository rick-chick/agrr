import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslateModule } from '@ngx-translate/core';

export type WizardProgressStepStatus = 'pending' | 'active' | 'completed';

export interface WizardProgressStepConfig {
  labelKey: string;
  status: WizardProgressStepStatus;
  routerLink?: string | string[];
}

@Component({
  selector: 'app-wizard-progress',
  standalone: true,
  imports: [RouterLink, TranslateModule],
  host: {
    'attr.wizardProgress': '',
  },
  template: `
    <div class="compact-progress" data-testid="wizard-progress">
      @for (step of steps; track step.labelKey; let index = $index) {
        <div
          class="compact-step"
          [class.active]="step.status === 'active'"
          [class.completed]="step.status === 'completed'"
        >
          <div class="step-number">{{ index + 1 }}</div>
          @if (step.status === 'completed' && step.routerLink) {
            <a [routerLink]="step.routerLink" class="step-label step-label-link">{{
              step.labelKey | translate
            }}</a>
          } @else {
            <span class="step-label">{{ step.labelKey | translate }}</span>
          }
        </div>
        @if (index < steps.length - 1) {
          <div
            class="compact-step-divider"
            [class.completed]="steps[index + 1].status !== 'pending'"
          ></div>
        }
      }
    </div>
  `,
  styleUrls: ['./wizard-progress.pattern.css'],
})
export class WizardProgressPattern {
  @Input({ required: true }) steps!: WizardProgressStepConfig[];
}
