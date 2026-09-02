import { Component, Input } from '@angular/core';
import {
  WizardProgressPattern,
  WizardProgressStepConfig,
} from '../shared/patterns/wizard-progress.pattern';

@Component({
  selector: 'app-entry-schedule-wizard-progress',
  standalone: true,
<<<<<<< HEAD
  imports: [RouterLink, TranslateModule],
  styleUrls: ['../public-plans/public-plan.component.css'],
=======
  imports: [WizardProgressPattern],
>>>>>>> origin/master
  host: {
    wizardProgress: '',
  },
  template: `<app-wizard-progress [steps]="steps" />`,
})
export class EntryScheduleWizardProgressComponent {
  @Input({ required: true }) set activeStep(value: 'farm' | 'crop') {
    this.steps = buildEntryScheduleWizardSteps(value);
  }

  steps: WizardProgressStepConfig[] = buildEntryScheduleWizardSteps('farm');
}

function buildEntryScheduleWizardSteps(activeStep: 'farm' | 'crop'): WizardProgressStepConfig[] {
  return [
    {
      labelKey: 'entrySchedule.steps.farm',
      status: activeStep === 'farm' ? 'active' : 'completed',
      routerLink: activeStep === 'crop' ? '/entry-schedule' : undefined,
    },
    {
      labelKey: 'entrySchedule.steps.crop',
      status: activeStep === 'crop' ? 'active' : 'pending',
    },
  ];
}
