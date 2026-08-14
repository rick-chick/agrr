import { Inject, Injectable } from '@angular/core';
import { forkJoin, of } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { localTodayIso } from '../../core/local-today';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';
import { PLAN_GATEWAY, PlanGateway } from '../plans/plan-gateway';
import { WORK_HUB_GATEWAY, WorkHubGateway } from './work-hub-gateway';
import { EnsurePlanForFarmUseCase } from './ensure-plan-for-farm.usecase';
import { loadHubFarmPlanCoreSummary } from './load-hub-farm-plan-core-summary';
import { loadHubFarmTaskCounts } from './load-hub-farm-task-counts';
import { WorkHubInitInputPort } from './work-hub-init.input-port';
import { WORK_HUB_INIT_OUTPUT_PORT, WorkHubInitOutputPort } from './work-hub-init.output-port';

type WorkHubFarmBase = Omit<
  WorkHubFarmRow,
  'overdueCount' | 'todayCount' | 'gddDelayCount' | 'thresholdExceededCount'
>;

function withZeroSummaries(farms: WorkHubFarmBase[]): WorkHubFarmRow[] {
  return farms.map((farm) => ({
    ...farm,
    overdueCount: 0,
    todayCount: 0,
    gddDelayCount: 0,
    thresholdExceededCount: 0
  }));
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
            return of({ farms: withZeroSummaries(farms), autoRedirect: false as const });
          }
          const farmPlans = farms.map((farm) => ({ farmId: farm.farmId, planId: farm.planId }));
          return forkJoin({
            taskCounts: loadHubFarmTaskCounts(farmPlans, this.planGateway, today, false),
            planCoreSummaries: loadHubFarmPlanCoreSummary(farmPlans, this.planGateway)
          }).pipe(
            map(({ taskCounts, planCoreSummaries }) => ({
              farms: farms.map((farm) => {
                const taskSummary = taskCounts.get(farm.farmId);
                const planCoreSummary = planCoreSummaries.get(farm.farmId);
                return {
                  ...farm,
                  overdueCount: taskSummary?.overdueCount ?? 0,
                  todayCount: taskSummary?.todayCount ?? 0,
                  gddDelayCount: planCoreSummary?.gddDelayCount ?? 0,
                  thresholdExceededCount: planCoreSummary?.thresholdExceededCount ?? 0
                };
              }),
              autoRedirect: false as const
            }))
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
