import { Inject, Injectable } from '@angular/core';
import { forkJoin, of } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { localTodayIso } from '../../core/local-today';
import { buildWorkHubPortfolioSummaryStats } from '../../domain/work-hub/build-work-hub-portfolio-summary-stats';
import { sortWorkHubFarmsByActionRequired } from '../../domain/work-hub/sort-work-hub-farms-by-action-required';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';
import { PLAN_GATEWAY, PlanGateway } from '../plans/plan-gateway';
import { WORK_HUB_GATEWAY, WorkHubGateway } from './work-hub-gateway';
import { EnsurePlanForFarmUseCase } from './ensure-plan-for-farm.usecase';
import { loadHubFarmTaskCounts } from './load-hub-farm-task-counts';
import { loadHubFarmVarianceStats } from './load-hub-farm-variance-stats';
import { WorkHubInitInputPort } from './work-hub-init.input-port';
import { WORK_HUB_INIT_OUTPUT_PORT, WorkHubInitOutputPort } from './work-hub-init.output-port';

function enrichFarmWithVariance(
  farm: Omit<
    WorkHubFarmRow,
    | 'overdueCount'
    | 'todayCount'
    | 'unrecordedCount'
    | 'gddDelayCount'
    | 'daysExceedanceCount'
    | 'thresholdExceededCount'
  >,
  variance: {
    unrecordedCount: number;
    gddDelayCount: number;
    daysExceedanceCount: number;
    thresholdExceededCount: number;
  } | undefined,
  counts?: { overdueCount: number; todayCount: number }
): WorkHubFarmRow {
  return {
    ...farm,
    overdueCount: counts?.overdueCount ?? 0,
    todayCount: counts?.todayCount ?? 0,
    unrecordedCount: variance?.unrecordedCount ?? 0,
    gddDelayCount: variance?.gddDelayCount ?? 0,
    daysExceedanceCount: variance?.daysExceedanceCount ?? 0,
    thresholdExceededCount: variance?.thresholdExceededCount ?? 0
  };
}

function withZeroCounts(
  farms: Omit<
    WorkHubFarmRow,
    | 'overdueCount'
    | 'todayCount'
    | 'unrecordedCount'
    | 'gddDelayCount'
    | 'daysExceedanceCount'
    | 'thresholdExceededCount'
  >[]
): WorkHubFarmRow[] {
  return farms.map((farm) => ({
    ...farm,
    overdueCount: 0,
    todayCount: 0,
    unrecordedCount: 0,
    gddDelayCount: 0,
    daysExceedanceCount: 0,
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
          const farmsForCounts = farms.map((farm) => ({ farmId: farm.farmId, planId: farm.planId }));
          const today = localTodayIso();

          if (farms.length === 1 && farms[0].hasValidFields) {
            if (farms[0].planId == null) {
              return of({ farms: withZeroCounts(farms), autoRedirect: true as const });
            }
            return loadHubFarmVarianceStats(farmsForCounts, this.planGateway).pipe(
              map((varianceByFarmId) => ({
                farms: [
                  enrichFarmWithVariance(farms[0], varianceByFarmId.get(farms[0].farmId))
                ],
                autoRedirect: true as const
              }))
            );
          }

          if (!farms.some((farm) => farm.planId != null)) {
            return of({ farms: withZeroCounts(farms), autoRedirect: false as const });
          }

          return forkJoin({
            countsByFarmId: loadHubFarmTaskCounts(
              farmsForCounts,
              this.planGateway,
              today,
              false
            ),
            varianceByFarmId: loadHubFarmVarianceStats(farmsForCounts, this.planGateway)
          }).pipe(
            map(({ countsByFarmId, varianceByFarmId }) => ({
              farms: sortWorkHubFarmsByActionRequired(
                farms.map((farm) =>
                  enrichFarmWithVariance(
                    farm,
                    varianceByFarmId.get(farm.farmId),
                    countsByFarmId.get(farm.farmId)
                  )
                )
              ),
              autoRedirect: false as const
            }))
          );
        })
      )
      .subscribe({
        next: ({ farms, autoRedirect }) => {
          const portfolioSummary = buildWorkHubPortfolioSummaryStats(farms);
          if (autoRedirect) {
            this.outputPort.present({ farms, portfolioSummary });
            this.outputPort.beginEnsure();
            this.ensurePlanForFarmUseCase.execute({
              farmId: farms[0].farmId,
              existingPlanId: farms[0].planId
            });
            return;
          }
          this.outputPort.present({ farms, portfolioSummary });
        },
        error: (err: unknown) =>
          this.outputPort.onError({
            message: err instanceof Error ? err.message : apiErrorI18nKey(err as never)
          })
      });
  }
}
