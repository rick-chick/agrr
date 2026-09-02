import { Component, Input } from '@angular/core';
import { WizardProgressPattern } from '../shared/patterns/wizard-progress.pattern';

@Component({
  selector: 'app-public-plan-wizard-progress',
  standalone: true,
  imports: [WizardProgressPattern],
  host: {
    wizardProgress: '',
  },
  template: `
    <app-wizard-progress-pattern
      [activeStep]="activeStep === 'region' ? 1 : 2"
      step1LabelKey="public_plans.steps.region"
      step2LabelKey="public_plans.steps.crop"
      [step1Link]="activeStep === 'crop' ? '/public-plans/new' : undefined"
    />
  `,
})
export class PublicPlanWizardProgressComponent {
  @Input({ required: true }) activeStep!: 'region' | 'crop';
}
