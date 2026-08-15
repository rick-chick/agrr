import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import {
  buildWorkHubAttentionList,
  type WorkHubAttentionItem
} from '../../domain/work-hub/build-work-hub-attention-list';
import { PlanGateway } from '../plans/plan-gateway';
import { loadHubFarmPlanVarianceData, type HubFarmForPlanSummary } from './load-hub-farm-plan-variance-data';

export function loadHubFarmAttentionItems(
  farms: HubFarmForPlanSummary[],
  planGateway: PlanGateway
): Observable<WorkHubAttentionItem[]> {
  return loadHubFarmPlanVarianceData(farms, planGateway).pipe(
    map((varianceByFarmId) =>
      buildWorkHubAttentionList(
        farms
          .filter((farm) => farm.planId != null)
          .map((farm) => ({
            farmId: farm.farmId,
            farmName: farm.farmName,
            planId: farm.planId!,
            actionItems: varianceByFarmId.get(farm.farmId)?.actionItems ?? []
          }))
      )
    )
  );
}
