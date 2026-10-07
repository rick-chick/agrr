import { Inject, Injectable } from '@angular/core';
import { map, switchMap } from 'rxjs/operators';
import { localTodayIso } from '../../core/local-today';
import { sumOverdueCounts } from '../../domain/work-schedule/work-day-list-summary';
import { PLAN_GATEWAY, PlanGateway } from '../plans/plan-gateway';
import { loadHubFarmTaskCounts } from '../work-hub/load-hub-farm-task-counts';
import { WORK_HUB_GATEWAY, WorkHubGateway } from '../work-hub/work-hub-gateway';
import { LoadNavOverdueBadgeInputPort } from './load-nav-overdue-badge.input-port';
import {
  LOAD_NAV_OVERDUE_BADGE_OUTPUT_PORT,
  LoadNavOverdueBadgeOutputPort
} from './load-nav-overdue-badge.output-port';

@Injectable()
export class LoadNavOverdueBadgeUseCase implements LoadNavOverdueBadgeInputPort {
  constructor(
    @Inject(LOAD_NAV_OVERDUE_BADGE_OUTPUT_PORT)
    private readonly outputPort: LoadNavOverdueBadgeOutputPort,
    @Inject(WORK_HUB_GATEWAY) private readonly workHubGateway: WorkHubGateway,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(): void {
    this.workHubGateway
      .listHubFarms()
      .pipe(
        switchMap((farms) => {
          const today = localTodayIso();
          return loadHubFarmTaskCounts(
            farms.map((farm) => ({ farmId: farm.farmId, planId: farm.planId })),
            this.planGateway,
            today,
            false
          ).pipe(
            map((countsByFarmId) =>
              sumOverdueCounts([...countsByFarmId.values()])
            )
          );
        })
      )
      .subscribe({
        next: (overdueCount) => this.outputPort.present({ overdueCount }),
        error: () => this.outputPort.present({ overdueCount: 0 })
      });
  }
}
