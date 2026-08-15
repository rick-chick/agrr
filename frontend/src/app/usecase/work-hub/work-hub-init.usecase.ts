import { Inject, Injectable } from '@angular/core';
import { forkJoin, of } from 'rxjs';
import { catchError, map, switchMap } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { localTodayIso } from '../../core/local-today';
import { buildWorkHubOtherVariancePlanCounts } from '../../domain/work-hub/build-work-hub-other-variance-plan-counts';
import { buildWorkHubPortfolioSummaryStats } from '../../domain/work-hub/build-work-hub-portfolio-summary-stats';
import type { WorkHubAttentionList } from '../../domain/work-hub/build-work-hub-attention-list';
import { buildWorkHubVarianceCoverageStats } from '../../domain/work-hub/build-work-hub-variance-coverage-stats';
import { sortWorkHubFarmsByActionRequired } from '../../domain/work-hub/sort-work-hub-farms-by-action-required';
import { WorkHubFarmRow, WorkHubListedFarm } from '../../domain/work-hub/work-hub-farm-row';
import type { VariancePortfolioRow } from '../../domain/work-variance-portfolio/variance-portfolio-row';
import { PLAN_GATEWAY, PlanGateway } from '../plans/plan-gateway';
import { WORK_VARIANCE_GATEWAY, WorkVarianceGateway } from '../work-variance/work-variance-gateway';
import { WORK_HUB_GATEWAY, WorkHubGateway } from './work-hub-gateway';
import { EnsurePlanForFarmUseCase } from './ensure-plan-for-farm.usecase';
import { loadHubFarmAttentionItems } from './load-hub-farm-attention-items';
import { loadHubFarmPlanVarianceData } from './load-hub-farm-plan-variance-data';
import { loadHubFarmTaskCounts } from './load-hub-farm-task-counts';
import { WorkHubInitInputPort } from './work-hub-init.input-port';
import { WORK_HUB_INIT_OUTPUT_PORT, WorkHubInitOutputPort } from './work-hub-init.output-port';

function enrichFarmWithVariance(
  farm: WorkHubListedFarm,
  variance: {
    unrecordedCount: number;
    gddDelayCount: number;
    daysExceedanceCount: number;
    thresholdExceededCount: number;
  } | undefined,
  counts?: { overdueCount: number; todayCount: number },
  otherVariancePlanCount = 0
): WorkHubFarmRow {
  return {
    ...farm,
    overdueCount: counts?.overdueCount ?? 0,
    todayCount: counts?.todayCount ?? 0,
    unrecordedCount: variance?.unrecordedCount ?? 0,
    gddDelayCount: variance?.gddDelayCount ?? 0,
    daysExceedanceCount: variance?.daysExceedanceCount ?? 0,
    thresholdExceededCount: variance?.thresholdExceededCount ?? 0,
    otherVariancePlanCount
  };
}

const EMPTY_ATTENTION_LIST: WorkHubAttentionList = { items: [] };

function presentHubData(
  outputPort: WorkHubInitOutputPort,
  farms: WorkHubFarmRow[],
  attentionList: WorkHubAttentionList,
  varianceCoverage: ReturnType<typeof buildWorkHubVarianceCoverageStats>,
  autoRedirect: boolean,
  ensurePlanForFarmUseCase: EnsurePlanForFarmUseCase
): void {
  const portfolioSummary = buildWorkHubPortfolioSummaryStats(farms);
  if (autoRedirect) {
    outputPort.present({ farms, portfolioSummary, varianceCoverage, attentionList });
    outputPort.beginEnsure();
    ensurePlanForFarmUseCase.execute({
      farmId: farms[0].farmId,
      existingPlanId: farms[0].planId
    });
    return;
  }
  outputPort.present({ farms, portfolioSummary, varianceCoverage, attentionList });
}

function applyOtherVariancePlanCounts(
  farms: WorkHubFarmRow[],
  portfolioRows: ReadonlyArray<VariancePortfolioRow>
): WorkHubFarmRow[] {
  const otherCounts = buildWorkHubOtherVariancePlanCounts(
    portfolioRows,
    farms.map((farm) => ({ farmId: farm.farmId, planId: farm.planId }))
  );
  return farms.map((farm) => ({
    ...farm,
    otherVariancePlanCount: otherCounts.get(farm.farmId) ?? 0
  }));
}

function withZeroCounts(farms: WorkHubListedFarm[]): WorkHubFarmRow[] {
  return farms.map((farm) => ({
    ...farm,
    overdueCount: 0,
    todayCount: 0,
    unrecordedCount: 0,
    gddDelayCount: 0,
    daysExceedanceCount: 0,
    thresholdExceededCount: 0,
    otherVariancePlanCount: 0
  }));
}

@Injectable()
export class WorkHubInitUseCase implements WorkHubInitInputPort {
  constructor(
    @Inject(WORK_HUB_INIT_OUTPUT_PORT) private readonly outputPort: WorkHubInitOutputPort,
    @Inject(WORK_HUB_GATEWAY) private readonly workHubGateway: WorkHubGateway,
    @Inject(WORK_VARIANCE_GATEWAY) private readonly workVarianceGateway: WorkVarianceGateway,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway,
    private readonly ensurePlanForFarmUseCase: EnsurePlanForFarmUseCase
  ) {}

  execute(): void {
    this.workHubGateway
      .listHubFarms()
      .pipe(
        switchMap((farms) => {
          const portfolioRows$ = this.workVarianceGateway.listVariancePortfolio().pipe(
            catchError(() => of([] as VariancePortfolioRow[]))
          );
          const farmsForCounts = farms.map((farm) => ({ farmId: farm.farmId, planId: farm.planId }));
          const farmsForSummary = farms.map((farm) => ({
            farmId: farm.farmId,
            farmName: farm.farmName,
            planId: farm.planId
          }));
          const today = localTodayIso();

          if (farms.length === 1 && farms[0].hasValidFields) {
            if (farms[0].planId == null) {
              return portfolioRows$.pipe(
                map((portfolioRows) => ({
                  farms: applyOtherVariancePlanCounts(withZeroCounts(farms), portfolioRows),
                  attentionList: EMPTY_ATTENTION_LIST,
                  varianceCoverage: buildWorkHubVarianceCoverageStats(portfolioRows),
                  autoRedirect: true as const
                }))
              );
            }
            return portfolioRows$.pipe(
              switchMap((portfolioRows) =>
                loadHubFarmPlanVarianceData(farmsForSummary, this.planGateway).pipe(
                  switchMap((varianceByFarmId) => {
                    const otherCounts = buildWorkHubOtherVariancePlanCounts(portfolioRows, farms);
                    const enrichedFarms = [
                      enrichFarmWithVariance(
                        farms[0],
                        varianceByFarmId.get(farms[0].farmId)?.stats,
                        undefined,
                        otherCounts.get(farms[0].farmId) ?? 0
                      )
                    ];
                    return loadHubFarmAttentionItems(farmsForSummary, this.planGateway).pipe(
                      map((attentionList) => ({
                        farms: enrichedFarms,
                        attentionList,
                        varianceCoverage: buildWorkHubVarianceCoverageStats(portfolioRows),
                        autoRedirect: true as const
                      }))
                    );
                  })
                )
              )
            );
          }

          if (!farms.some((farm) => farm.planId != null)) {
            return portfolioRows$.pipe(
              map((portfolioRows) => ({
                farms: applyOtherVariancePlanCounts(withZeroCounts(farms), portfolioRows),
                attentionList: EMPTY_ATTENTION_LIST,
                varianceCoverage: buildWorkHubVarianceCoverageStats(portfolioRows),
                autoRedirect: false as const
              }))
            );
          }

          return portfolioRows$.pipe(
            switchMap((portfolioRows) =>
              forkJoin({
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
                  farms: applyOtherVariancePlanCounts(
                    sortWorkHubFarmsByActionRequired(
                      farms.map((farm) =>
                        enrichFarmWithVariance(
                          farm,
                          varianceByFarmId.get(farm.farmId)?.stats,
                          countsByFarmId.get(farm.farmId)
                        )
                      )
                    ),
                    portfolioRows
                  ),
                  attentionList,
                  varianceCoverage: buildWorkHubVarianceCoverageStats(portfolioRows),
                  autoRedirect: false as const
                }))
              )
            )
          );
        })
      )
      .subscribe({
        next: ({ farms, attentionList, varianceCoverage, autoRedirect }) => {
          presentHubData(
            this.outputPort,
            farms,
            attentionList,
            varianceCoverage,
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
