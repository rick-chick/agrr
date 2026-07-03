import { Injectable } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';

import { GanttChartView } from '../../components/plans/gantt-chart.view';
import {
  GanttPlanMutationOutcome,
  resolveGanttPlanMutationFailureAction
} from '../../domain/plans/gantt-plan-mutation';
import { GANTT_I18N_KEYS } from '../../core/i18n/gantt-locale.keys';
import { pendingErrorFlashFromError } from '../../core/view-effects/pending-error-flash-presenter.helpers';
import {
  LoadGanttPlanDataEmptyDto,
  LoadGanttPlanDataErrorDto,
  LoadGanttPlanDataLoadedDto
} from '../../usecase/plans/load-gantt-plan-data.dtos';
import { LoadGanttPlanDataOutputPort } from '../../usecase/plans/load-gantt-plan-data.output-port';
import { RunGanttPlanMutationOutputPort } from '../../usecase/plans/run-gantt-plan-mutation.output-port';
import { RunGanttPlanMutationResultDto } from '../../usecase/plans/run-gantt-plan-mutation.dtos';
import { GanttMutationPresentationOptions } from '../../usecase/plans/run-gantt-plan-mutation.dtos';

@Injectable()
export class GanttChartPresenter implements LoadGanttPlanDataOutputPort, RunGanttPlanMutationOutputPort {
  private view: GanttChartView | null = null;

  constructor(private readonly translate: TranslateService) {}

  setView(view: GanttChartView): void {
    this.view = view;
  }

  onMutationOutcome(outcome: GanttPlanMutationOutcome, context: RunGanttPlanMutationResultDto): void {
    if (this.view) {
      this.view.setFieldFormLoading(false);
    }
    this.applyMutationOutcome(outcome, context.planId, context.presentation);
  }

  onPlanDataLoaded(dto: LoadGanttPlanDataLoadedDto): void {
    if (!this.view) {
      throw new Error('GanttChartPresenter: view not set');
    }
    if (dto.purpose === 'refresh') {
      this.view.applyRefreshedPlanData(dto.data);
      return;
    }
    this.view.applyBarResetPlanData(dto.data);
  }

  onPlanDataEmpty(dto: LoadGanttPlanDataEmptyDto): void {
    if (!this.view) {
      throw new Error('GanttChartPresenter: view not set');
    }
    if (dto.purpose === 'refresh') {
      this.view.clearOptimizationLock();
    }
  }

  onLoadError(dto: LoadGanttPlanDataErrorDto): void {
    this.showOperationError(dto.message);
  }

  private applyMutationOutcome(
    outcome: GanttPlanMutationOutcome,
    planId: number,
    options: GanttMutationPresentationOptions = {}
  ): void {
    if (!this.view) {
      throw new Error('GanttChartPresenter: view not set');
    }

    if (outcome.status === 'failure') {
      const action = resolveGanttPlanMutationFailureAction(outcome.failure, options);
      switch (action.kind) {
        case 'refetch_failed':
          this.showOperationError(GANTT_I18N_KEYS.js.logs.dataRefetchFailed);
          if (action.recovery === 'update_chart') {
            this.view.updateChartOnly();
          } else {
            this.view.requestPlanRefresh(planId);
          }
          return;
        case 'refetch_error':
          this.showOperationError(GANTT_I18N_KEYS.js.logs.dataRefetchApiError);
          if (action.recovery === 'update_chart') {
            this.view.updateChartOnly();
          } else {
            this.view.requestPlanRefresh(planId);
          }
          return;
        case 'message':
          this.showOperationError(action.message);
          if (action.revertBar) {
            this.view.resetBarPosition();
          }
          return;
      }
    }

    const onSuccess = options.onSuccess ?? ((data) => this.view!.applyRefreshedPlanData(data));
    onSuccess(outcome.data);
  }

  private showOperationError(message?: string): void {
    if (!this.view) {
      throw new Error('GanttChartPresenter: view not set');
    }

    const text = this.formatErrorText(message);
    this.view.control = {
      ...this.view.control,
      pendingErrorFlash: pendingErrorFlashFromError({ message: text })
    };
    this.view.setFieldFormLoading(false);
    this.view.clearOptimizationLock();
  }

  private formatErrorText(message?: string): string {
    if (!message) {
      return this.translate.instant(GANTT_I18N_KEYS.adjustFailed);
    }
    if (message.includes('.')) {
      return this.translate.instant(message);
    }
    return message;
  }
}
