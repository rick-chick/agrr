import { forkJoin, Observable, of } from 'rxjs';
import { map } from 'rxjs/operators';
import { buildPlanWorkVarianceSummaryStats } from '../../domain/plans/build-plan-work-variance-summary-stats';
import { PlanGateway } from '../plans/plan-gateway';
import type { HubFarmForTaskCounts } from './load-hub-farm-task-counts';

export interface HubFarmPlanCoreSummary {
  gddDelayCount: number;
  thresholdExceededCount: number;
}

export function loadHubFarmPlanCoreSummary(
  farms: HubFarmForTaskCounts[],
  planGateway: PlanGateway
): Observable<Map<number, HubFarmPlanCoreSummary>> {
  if (!farms.some((farm) => farm.planId != null)) {
    return of(new Map());
  }

  return forkJoin(
    farms.map((farm) => {
      if (farm.planId == null) {
        return of({
          farmId: farm.farmId,
          gddDelayCount: 0,
          thresholdExceededCount: 0
        });
      }
      return planGateway.getPlanVsActualSummary(farm.planId).pipe(
        map((summary) => {
          const stats = buildPlanWorkVarianceSummaryStats(summary);
          return {
            farmId: farm.farmId,
            gddDelayCount: stats.gddDelayCount,
            thresholdExceededCount: stats.thresholdExceededCount
          };
        })
      );
    })
  ).pipe(
    map(
      (summaries) =>
        new Map(
          summaries.map((summary) => [
            summary.farmId,
            {
              gddDelayCount: summary.gddDelayCount,
              thresholdExceededCount: summary.thresholdExceededCount
            }
          ])
        )
    )
  );
}
