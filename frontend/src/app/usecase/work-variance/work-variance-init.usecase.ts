import { Inject, Injectable } from '@angular/core';
import { switchMap, map } from 'rxjs/operators';
import { apiErrorI18nKey } from '../../core/api-error-i18n-key';
import { buildVariancePortfolioSummaryStats } from '../../domain/work-variance-portfolio/build-variance-portfolio-summary-stats';
import { collectVariancePortfolioFilterOptions } from '../../domain/work-variance-portfolio/collect-variance-portfolio-filter-options';
import { filterVariancePortfolioRows } from '../../domain/work-variance-portfolio/filter-variance-portfolio-rows';
import { groupVariancePortfolioByFarm } from '../../domain/work-variance-portfolio/group-variance-portfolio-by-farm';
import {
  EMPTY_VARIANCE_PORTFOLIO_FILTERS,
  type VariancePortfolioFilters
} from '../../domain/work-variance-portfolio/variance-portfolio-filters';
import type { VariancePortfolioRow } from '../../domain/work-variance-portfolio/variance-portfolio-row';
import { PLAN_GATEWAY, PlanGateway } from '../plans/plan-gateway';
import { loadVariancePortfolioAttentionItems } from './load-variance-portfolio-attention-items';
import { WorkVarianceInitInputPort } from './work-variance-init.input-port';
import { WorkVarianceInitPresentDto } from './work-variance-init.dtos';
import {
  WORK_VARIANCE_INIT_OUTPUT_PORT,
  WorkVarianceInitOutputPort
} from './work-variance-init.output-port';
import { WORK_VARIANCE_GATEWAY, WorkVarianceGateway } from './work-variance-gateway';

function buildPresentDto(
  rows: VariancePortfolioRow[],
  filters: VariancePortfolioFilters,
  attentionList: WorkVarianceInitPresentDto['attentionList']
): WorkVarianceInitPresentDto {
  const filteredRows = filterVariancePortfolioRows(rows, filters);
  return {
    rows,
    filters,
    filterOptions: collectVariancePortfolioFilterOptions(rows),
    farmGroups: groupVariancePortfolioByFarm(filteredRows),
    portfolioSummary: buildVariancePortfolioSummaryStats(filteredRows),
    attentionList
  };
}

@Injectable()
export class WorkVarianceInitUseCase implements WorkVarianceInitInputPort {
  private cachedRows: VariancePortfolioRow[] = [];
  private cachedAttentionList: WorkVarianceInitPresentDto['attentionList'] = { items: [] };
  private currentFilters: VariancePortfolioFilters = { ...EMPTY_VARIANCE_PORTFOLIO_FILTERS };

  constructor(
    @Inject(WORK_VARIANCE_INIT_OUTPUT_PORT) private readonly outputPort: WorkVarianceInitOutputPort,
    @Inject(WORK_VARIANCE_GATEWAY) private readonly workVarianceGateway: WorkVarianceGateway,
    @Inject(PLAN_GATEWAY) private readonly planGateway: PlanGateway
  ) {}

  execute(): void {
    this.currentFilters = { ...EMPTY_VARIANCE_PORTFOLIO_FILTERS };
    this.workVarianceGateway
      .listVariancePortfolio()
      .pipe(
        switchMap((rows) =>
          loadVariancePortfolioAttentionItems(rows, this.planGateway).pipe(
            map((attentionList) => ({ rows, attentionList }))
          )
        )
      )
      .subscribe({
        next: ({ rows, attentionList }) => {
          this.cachedRows = rows;
          this.cachedAttentionList = attentionList;
          this.outputPort.present(buildPresentDto(rows, this.currentFilters, attentionList));
        },
        error: (err: unknown) =>
          this.outputPort.onError({
            message: err instanceof Error ? err.message : apiErrorI18nKey(err as never)
          })
      });
  }

  applyFilters(filters: VariancePortfolioFilters): void {
    this.currentFilters = { ...filters };
    this.outputPort.present(
      buildPresentDto(this.cachedRows, this.currentFilters, this.cachedAttentionList)
    );
  }
}
