import { Inject, Injectable } from '@angular/core';
import { forkJoin, of } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { localTodayIso } from '../../core/local-today';
import { countWorkDayListFromFields } from '../../domain/work-schedule/work-day-list-summary';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';
import { PLAN_GATEWAY, PlanGateway } from '../plans/plan-gateway';
import { WORK_HUB_GATEWAY, WorkHubGateway } from './work-hub-gateway';
import { EnsurePlanForFarmUseCase } from './ensure-plan-for-farm.usecase';
import { WorkHubInitInputPort } from './work-hub-init.input-port';
import { WORK_HUB_INIT_OUTPUT_PORT, WorkHubInitOutputPort } from './work-hub-init.output-port';

function withZeroCounts(farms: Omit<WorkHubFarmRow, 'overdueCount' | 'todayCount'>[]): WorkHubFarmRow[] {
  return farms.map((farm) => ({ ...farm, overdueCount: 0, todayCount: 0 }));
}

@Injectable()
export class WorkHubInitUseCase implements WorkHubInitInputPort {
  constructor(
    @Inject(WORK_HUB_INIT_OUTPUT_PORT) private readonly outputPort: WorkHubInitOutputPort,
    @Inject(WORK_HUB_GATEWAY) private readonly workHubGateway: WorkHubGateway,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway,
    private readonly ensurePlanForFarmUseCase: EnsurePlanForFarmUseCase
  ) {}

  execute(): void {
    this.workHubGateway
      .listHubFarms()
      .pipe(
        switchMap((farms) => {
          if (farms.length === 1 && farms[0].hasValidFields) {
            return of({ farms, autoRedirect: true as const });
          }
          const today = localTodayIso();
          if (!farms.some((farm) => farm.planId != null)) {
            return of({ farms: withZeroCounts(farms), autoRedirect: false as const });
          }
          return forkJoin(
            farms.map((farm) => {
              if (farm.planId == null) {
                return of({ farmId: farm.farmId, overdueCount: 0, todayCount: 0 });
              }
              return this.planGateway.getTaskSchedule(farm.planId).pipe(
                map((schedule) => ({
                  farmId: farm.farmId,
                  ...countWorkDayListFromFields(schedule.fields, today, false)
                }))
              );
            })
          ).pipe(
            map((summaries) => {
              const byFarmId = new Map(summaries.map((summary) => [summary.farmId, summary]));
              return {
                farms: farms.map((farm) => {
                  const summary = byFarmId.get(farm.farmId);
                  return {
                    ...farm,
                    overdueCount: summary?.overdueCount ?? 0,
                    todayCount: summary?.todayCount ?? 0
                  };
                }),
                autoRedirect: false as const
              };
            })
          );
        })
      )
      .subscribe({
        next: ({ farms, autoRedirect }) => {
          if (autoRedirect) {
            this.outputPort.present({ farms });
            this.outputPort.beginEnsure();
            this.ensurePlanForFarmUseCase.execute({
              farmId: farms[0].farmId,
              existingPlanId: farms[0].planId
            });
            return;
          }
          this.outputPort.present({ farms });
        },
        error: (err: unknown) =>
          this.outputPort.onError({
            message: err instanceof Error ? err.message : apiErrorI18nKey(err as never)
          })
      });
  }
}
