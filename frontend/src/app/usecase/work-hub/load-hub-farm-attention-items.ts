import { forkJoin, Observable, of } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import {
  buildWorkHubAttentionList,
  type HubFarmWeatherTriggerSource,
  type WorkHubAttentionList
} from '../../domain/work-hub/build-work-hub-attention-list';
import type { VariancePortfolioRow } from '../../domain/work-variance-portfolio/variance-portfolio-row';
import type { WeatherRescheduleTriggerType } from '../../domain/plans/weather-reschedule-proposal';
import { PlanGateway } from '../plans/plan-gateway';
import { loadHubFarmPlanVarianceData, type HubFarmForPlanSummary } from './load-hub-farm-plan-variance-data';

function uniqueWeatherTriggerTypes(
  triggerTypes: WeatherRescheduleTriggerType[]
): WeatherRescheduleTriggerType[] {
  return [...new Set(triggerTypes)];
}

function weatherTriggerSourcesFromPortfolio(
  farms: HubFarmForPlanSummary[],
  portfolioRows: ReadonlyArray<VariancePortfolioRow>,
  proposalsByPlanId: ReadonlyMap<number, WeatherRescheduleTriggerType[]>
): HubFarmWeatherTriggerSource[] {
  return farms
    .filter((farm) => farm.planId != null)
    .flatMap((farm) => {
      const portfolioRow = portfolioRows.find((row) => row.planId === farm.planId);
      const count = portfolioRow?.weatherTriggerCount ?? 0;
      if (count <= 0) {
        return [];
      }
      return [
        {
          farmId: farm.farmId,
          farmName: farm.farmName,
          planId: farm.planId!,
          count,
          triggerTypes: proposalsByPlanId.get(farm.planId!) ?? []
        }
      ];
    });
}

export function loadHubFarmAttentionItems(
  farms: HubFarmForPlanSummary[],
  planGateway: PlanGateway,
  portfolioRows: ReadonlyArray<VariancePortfolioRow> = []
): Observable<WorkHubAttentionList> {
  return loadHubFarmPlanVarianceData(farms, planGateway).pipe(
    switchMap((varianceByFarmId) => {
      const farmsWithPlans = farms.filter((farm) => farm.planId != null);
      const weatherFarms = farmsWithPlans.filter((farm) => {
        const portfolioRow = portfolioRows.find((row) => row.planId === farm.planId);
        return (portfolioRow?.weatherTriggerCount ?? 0) > 0;
      });

      const weatherRequests = weatherFarms.map((farm) =>
        planGateway.getWeatherRescheduleProposals(farm.planId!).pipe(
          map((proposals) => ({
            planId: farm.planId!,
            triggerTypes: uniqueWeatherTriggerTypes(
              proposals.map((proposal) => proposal.trigger_type)
            )
          }))
        )
      );

      const weatherData$ = weatherRequests.length ? forkJoin(weatherRequests) : of([]);

      return weatherData$.pipe(
        map((weatherData) => {
          const proposalsByPlanId = new Map(
            weatherData.map((entry) => [entry.planId, entry.triggerTypes])
          );
          const varianceSources = farmsWithPlans.map((farm) => ({
            farmId: farm.farmId,
            farmName: farm.farmName,
            planId: farm.planId!,
            actionItems: varianceByFarmId.get(farm.farmId)?.actionItems ?? []
          }));
          const weatherSources = weatherTriggerSourcesFromPortfolio(
            farms,
            portfolioRows,
            proposalsByPlanId
          );

          return buildWorkHubAttentionList(varianceSources, weatherSources);
        })
      );
    })
  );
}
