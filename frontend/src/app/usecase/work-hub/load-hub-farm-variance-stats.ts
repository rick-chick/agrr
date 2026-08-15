import { Observable, of } from 'rxjs';
import { map } from 'rxjs/operators';
import { PlanGateway } from '../plans/plan-gateway';
import {
  loadHubFarmPlanVarianceData,
  type HubFarmForPlanSummary
} from './load-hub-farm-plan-variance-data';

export interface HubFarmVarianceStats {
  unrecordedCount: number;
  gddDelayCount: number;
  daysExceedanceCount: number;
  thresholdExceededCount: number;
}

export interface HubFarmForVarianceStats {
  farmId: number;
  planId: number | null;
}

export function loadHubFarmVarianceStats(
  farms: HubFarmForVarianceStats[],
  planGateway: PlanGateway
): Observable<Map<number, HubFarmVarianceStats>> {
  const farmsForSummary: HubFarmForPlanSummary[] = farms.map((farm) => ({
    farmId: farm.farmId,
    farmName: '',
    planId: farm.planId
  }));

  if (!farms.some((farm) => farm.planId != null)) {
    return of(new Map());
  }

  return loadHubFarmPlanVarianceData(farmsForSummary, planGateway).pipe(
    map(
      (varianceByFarmId) =>
        new Map(
          [...varianceByFarmId.entries()].map(([farmId, data]) => [farmId, data.stats])
        )
    )
  );
}
