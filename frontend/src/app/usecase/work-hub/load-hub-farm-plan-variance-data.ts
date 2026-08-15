import { forkJoin, Observable, of } from 'rxjs';
import { map } from 'rxjs/operators';
import { buildPlanWorkVarianceSummaryStats } from '../../domain/plans/build-plan-work-variance-summary-stats';
import type { PlanVarianceActionItem } from '../../domain/plans/plan-vs-actual-summary';
import { PlanGateway } from '../plans/plan-gateway';
import type { HubFarmVarianceStats } from './load-hub-farm-variance-stats';

export interface HubFarmForPlanSummary {
  farmId: number;
  farmName: string;
  planId: number | null;
}

export interface HubFarmPlanVarianceData {
  stats: HubFarmVarianceStats;
  actionItems: PlanVarianceActionItem[];
}

export function loadHubFarmPlanVarianceData(
  farms: HubFarmForPlanSummary[],
  planGateway: PlanGateway
): Observable<Map<number, HubFarmPlanVarianceData>> {
  if (!farms.some((farm) => farm.planId != null)) {
    return of(new Map());
  }

  return forkJoin(
    farms.map((farm) => {
      if (farm.planId == null) {
        return of({
          farmId: farm.farmId,
          stats: {
            unrecordedCount: 0,
            gddDelayCount: 0,
            daysExceedanceCount: 0,
            thresholdExceededCount: 0
          },
          actionItems: [] as PlanVarianceActionItem[]
        });
      }

      return planGateway.getPlanVsActualSummary(farm.planId).pipe(
        map((summary) => {
          const stats = buildPlanWorkVarianceSummaryStats(summary);
          return {
            farmId: farm.farmId,
            stats: {
              unrecordedCount: stats.unrecordedCount,
              gddDelayCount: stats.gddDelayCount,
              daysExceedanceCount: stats.daysExceedanceCount,
              thresholdExceededCount: stats.thresholdExceededCount
            },
            actionItems: summary.action_required_items ?? []
          };
        })
      );
    })
  ).pipe(
    map(
      (entries) =>
        new Map(entries.map((entry) => [entry.farmId, { stats: entry.stats, actionItems: entry.actionItems }]))
    )
  );
}
