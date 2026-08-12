import { forkJoin, Observable, of } from 'rxjs';
import { map } from 'rxjs/operators';
import {
  countWorkDayListFromFields,
  WorkDayListCounts
} from '../../domain/work-schedule/work-day-list-summary';
import { PlanGateway } from '../plans/plan-gateway';

export interface HubFarmForTaskCounts {
  farmId: number;
  planId: number | null;
}

export function loadHubFarmTaskCounts(
  farms: HubFarmForTaskCounts[],
  planGateway: PlanGateway,
  today: string,
  includeSkipped = false
): Observable<Map<number, WorkDayListCounts>> {
  if (!farms.some((farm) => farm.planId != null)) {
    return of(new Map());
  }

  return forkJoin(
    farms.map((farm) => {
      if (farm.planId == null) {
        return of({ farmId: farm.farmId, overdueCount: 0, todayCount: 0 });
      }
      return planGateway.getTaskSchedule(farm.planId).pipe(
        map((schedule) => ({
          farmId: farm.farmId,
          ...countWorkDayListFromFields(schedule.fields, today, includeSkipped)
        }))
      );
    })
  ).pipe(
    map(
      (summaries) =>
        new Map(
          summaries.map((summary) => [
            summary.farmId,
            { overdueCount: summary.overdueCount, todayCount: summary.todayCount }
          ])
        )
    )
  );
}
