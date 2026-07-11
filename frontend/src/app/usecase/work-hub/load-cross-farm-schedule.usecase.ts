import { Inject, Injectable } from '@angular/core';
import { forkJoin, of } from 'rxjs';
import { catchError, map, switchMap } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { flattenCrossFarmSchedules } from '../../domain/work-schedule/flatten-cross-farm-schedule';
import type { CrossFarmScheduleSource } from '../../domain/work-schedule/cross-farm-schedule-row';
import { PLAN_GATEWAY, PlanGateway } from '../plans/plan-gateway';
import { WORK_HUB_GATEWAY, WorkHubGateway } from './work-hub-gateway';
import { LoadCrossFarmScheduleInputPort } from './load-cross-farm-schedule.input-port';
import {
  LOAD_CROSS_FARM_SCHEDULE_OUTPUT_PORT,
  LoadCrossFarmScheduleOutputPort
} from './load-cross-farm-schedule.output-port';

@Injectable()
export class LoadCrossFarmScheduleUseCase implements LoadCrossFarmScheduleInputPort {
  constructor(
    @Inject(LOAD_CROSS_FARM_SCHEDULE_OUTPUT_PORT)
    private readonly outputPort: LoadCrossFarmScheduleOutputPort,
    @Inject(WORK_HUB_GATEWAY) private readonly workHubGateway: WorkHubGateway,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(): void {
    this.outputPort.beginScheduleLoad();
    this.workHubGateway
      .listHubFarms()
      .pipe(
        switchMap((farms) => {
          const farmsWithPlans = farms.filter((farm) => farm.planId != null);
          if (farmsWithPlans.length === 0) {
            return of([] as CrossFarmScheduleSource[]);
          }
          return forkJoin(
            farmsWithPlans.map((farm) =>
              this.planGateway.getTaskSchedule(farm.planId!, { scope: 'plan' }).pipe(
                map(
                  (schedule): CrossFarmScheduleSource => ({
                    farmId: farm.farmId,
                    farmName: farm.farmName,
                    planId: farm.planId!,
                    planName: schedule.plan.name,
                    fields: schedule.fields
                  })
                )
              )
            )
          );
        }),
        map((sources) => flattenCrossFarmSchedules(sources)),
        catchError((err: unknown) => {
          this.outputPort.onScheduleError({ message: apiErrorI18nKey(err) });
          return of(null);
        })
      )
      .subscribe((rows) => {
        if (rows == null) {
          return;
        }
        this.outputPort.presentSchedule({ rows });
      });
  }
}
