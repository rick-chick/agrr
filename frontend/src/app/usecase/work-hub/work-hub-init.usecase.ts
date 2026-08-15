import { Inject, Injectable } from '@angular/core';
import { forkJoin, of } from 'rxjs';
import { map, switchMap } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { localTodayIso } from '../../core/local-today';
import { buildWorkHubPortfolioSummaryStats } from '../../domain/work-hub/build-work-hub-portfolio-summary-stats';
import type { WorkHubAttentionList } from '../../domain/work-hub/build-work-hub-attention-list';
import { sortWorkHubFarmsByActionRequired } from '../../domain/work-hub/sort-work-hub-farms-by-action-required';
import { WorkHubFarmRow } from '../../domain/work-hub/work-hub-farm-row';
import { PLAN_GATEWAY, PlanGateway } from '../plans/plan-gateway';
import { WORK_HUB_GATEWAY, WorkHubGateway } from './work-hub-gateway';
import { EnsurePlanForFarmUseCase } from './ensure-plan-for-farm.usecase';
import { loadHubFarmAttentionItems } from './load-hub-farm-attention-items';
import { loadHubFarmPlanVarianceData } from './load-hub-farm-plan-variance-data';
import { loadHubFarmTaskCounts } from './load-hub-farm-task-counts';
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

const EMPTY_ATTENTION_LIST: WorkHubAttentionList = { items: [] };

function presentHubData(
  outputPort: WorkHubInitOutputPort,
  farms: WorkHubFarmRow[],
  attentionList: WorkHubAttentionList,
  autoRedirect: boolean,
  ensurePlanForFarmUseCase: EnsurePlanForFarmUseCase
): void {
  const portfolioSummary = buildWorkHubPortfolioSummaryStats(farms);
  if (autoRedirect) {
    outputPort.present({ farms, portfolioSummary, attentionList });
    outputPort.beginEnsure();
    ensurePlanForFarmUseCase.execute({
      farmId: farms[0].farmId,
      existingPlanId: farms[0].planId
    });
    return;
  }
  outputPort.present({ farms, portfolioSummary, attentionList });
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
          const farmsForSummary = farms.map((farm) => ({
            farmId: farm.farmId,
            farmName: farm.farmName,
            planId: farm.planId
          }));
          const today = localTodayIso();

          if (farms.length === 1 && farms[0].hasValidFields) {
            if (farms[0].planId == null) {
              return of({
                farms: withZeroCounts(farms),
                attentionList: EMPTY_ATTENTION_LIST,
                autoRedirect: true as const
              });
            }
            return loadHubFarmPlanVarianceData(farmsForSummary, this.planGateway).pipe(
              switchMap((varianceByFarmId) => {
                const enrichedFarms = [
                  enrichFarmWithVariance(farms[0], varianceByFarmId.get(farms[0].farmId)?.stats)
                ];
                return loadHubFarmAttentionItems(farmsForSummary, this.planGateway).pipe(
                  map((attentionList) => ({
                    farms: enrichedFarms,
                    attentionList,
                    autoRedirect: true as const
                  }))
                );
              })
            );
          }

          if (!farms.some((farm) => farm.planId != null)) {
            return of({
              farms: withZeroCounts(farms),
              attentionList: EMPTY_ATTENTION_LIST,
              autoRedirect: false as const
            });
          }

          return forkJoin({
            countsByFarmId: loadHubFarmTaskCounts(
              farmsForCounts,
              this.planGateway,
              today,
              false
            ),
            varianceByFarmId: loadHubFarmPlanVarianceData(farmsForSummary, this.planGateway),
            attentionList: loadHubFarmAttentionItems(farmsForSummary, this.planGateway)
          }).pipe(
            map(({ countsByFarmId, varianceByFarmId, attentionList }) => ({
              farms: sortWorkHubFarmsByActionRequired(
                farms.map((farm) =>
                  enrichFarmWithVariance(
                    farm,
                    varianceByFarmId.get(farm.farmId)?.stats,
                    countsByFarmId.get(farm.farmId)
                  )
                )
              ),
              attentionList,
              autoRedirect: false as const
            }))
          );
        })
      )
      .subscribe({
        next: ({ farms, attentionList, autoRedirect }) => {
          presentHubData(
            this.outputPort,
            farms,
            attentionList,
            autoRedirect,
            this.ensurePlanForFarmUseCase
          );
        },
        error: (err: unknown) =>
          this.outputPort.onError({
            message: err instanceof Error ? err.message : apiErrorI18nKey(err as never)
          })
      });
  }
}
