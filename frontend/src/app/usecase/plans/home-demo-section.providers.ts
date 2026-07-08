import { Provider } from '@angular/core';
import { HomeDemoSectionPresenter } from '../../adapters/plans/home-demo-section.presenter';
import { GANTT_CHART_DEMO_PROVIDERS } from './gantt-chart.providers';
import { PLAN_FIELD_CLIMATE_DEMO_PROVIDERS } from './plan-field-climate.providers';
import { SYNC_LANDING_DEMO_PLAN_OUTPUT_PORT } from './sync-landing-demo-plan.output-port';
import { SyncLandingDemoPlanUseCase } from './sync-landing-demo-plan.usecase';

export const HOME_DEMO_SECTION_PROVIDERS: readonly Provider[] = [
  HomeDemoSectionPresenter,
  SyncLandingDemoPlanUseCase,
  { provide: SYNC_LANDING_DEMO_PLAN_OUTPUT_PORT, useExisting: HomeDemoSectionPresenter },
  ...GANTT_CHART_DEMO_PROVIDERS,
  ...PLAN_FIELD_CLIMATE_DEMO_PROVIDERS
];

export { HomeDemoSectionPresenter } from '../../adapters/plans/home-demo-section.presenter';
