import { Provider } from '@angular/core';
import { PlanApiGateway } from '../../adapters/plans/plan-api.gateway';
import { NavOverdueBadgePresenter } from '../../adapters/nav/nav-overdue-badge.presenter';
import { PLAN_GATEWAY } from '../plans/plan-gateway';
import { WORK_HUB_GATEWAY } from '../work-hub/work-hub-gateway';
import { WorkHubApiGateway } from '../../adapters/work-hub/work-hub-api.gateway';
import { LOAD_NAV_OVERDUE_BADGE_OUTPUT_PORT } from './load-nav-overdue-badge.output-port';
import { LoadNavOverdueBadgeUseCase } from './load-nav-overdue-badge.usecase';

export const NAV_OVERDUE_BADGE_PROVIDERS: readonly Provider[] = [
  NavOverdueBadgePresenter,
  LoadNavOverdueBadgeUseCase,
  { provide: LOAD_NAV_OVERDUE_BADGE_OUTPUT_PORT, useExisting: NavOverdueBadgePresenter },
  { provide: WORK_HUB_GATEWAY, useClass: WorkHubApiGateway },
  { provide: PLAN_GATEWAY, useClass: PlanApiGateway }
];

export { NavOverdueBadgePresenter } from '../../adapters/nav/nav-overdue-badge.presenter';
