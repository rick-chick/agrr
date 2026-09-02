import { Component, Input } from '@angular/core';
import { WizardProgressPattern } from '../shared/patterns/wizard-progress.pattern';

@Component({
  selector: 'app-entry-schedule-wizard-progress',
  standalone: true,
  imports: [WizardProgressPattern],
  host: {
    wizardProgress: '',
  },
  template: `
    <app-wizard-progress-pattern
      [activeStep]="activeStep === 'farm' ? 1 : 2"
      step1LabelKey="entrySchedule.steps.farm"
      step2LabelKey="entrySchedule.steps.crop"
      [step1Link]="activeStep === 'crop' ? '/entry-schedule' : undefined"
    />
  `,
})
export class EntryScheduleWizardProgressComponent {
  @Input({ required: true }) activeStep!: 'farm' | 'crop';
}
