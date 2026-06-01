import { Injectable } from '@angular/core';
import { HttpErrorResponse } from '@angular/common/http';
import { TranslateService } from '@ngx-translate/core';

import { GanttChartView } from '../../components/plans/gantt-chart.view';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { CultivationPlanContextType } from '../../domain/plans/cultivation-plan-context-type';
import { resolveGanttPlanMutationFailureAction } from '../../domain/plans/gantt-plan-mutation';
import {
  extractHttpErrorMessage,
  GanttPlanCoordinatorService,
  GanttPlanMutationOutcome
} from '../../services/plans/gantt-plan-coordinator.service';
import { FlashMessageService } from '../../services/flash-message.service';
import { GANTT_I18N_KEYS } from '../../core/i18n/gantt-locale.keys';

@Injectable()
export class GanttChartPresenter {
  private view: GanttChartView | null = null;
  private planType: CultivationPlanContextType = 'private';

  constructor(
    private readonly translate: TranslateService,
    private readonly flashMessageService: FlashMessageService,
    private readonly ganttPlanCoordinator: GanttPlanCoordinatorService
  ) {}

  setView(view: GanttChartView): void {
    this.view = view;
  }

  bindPlanContext(planType: CultivationPlanContextType): void {
    this.planType = planType;
  }

  applyMutationOutcome(
    outcome: GanttPlanMutationOutcome,
    planId: number,
    options: {
      onRefetchFailure?: 'refresh' | 'update_chart';
      revertBarOnMessageFailure?: boolean;
      onSuccess?: (data: CultivationPlanData) => void;
    } = {}
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
            this.refreshPlanData(planId);
          }
          return;
        case 'refetch_error':
          this.showOperationError(GANTT_I18N_KEYS.js.logs.dataRefetchApiError);
          if (action.recovery === 'update_chart') {
            this.view.updateChartOnly();
          } else {
            this.refreshPlanData(planId);
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

  refreshPlanData(planId: number): void {
    if (!this.view) {
      throw new Error('GanttChartPresenter: view not set');
    }

    this.ganttPlanCoordinator.loadPlanData(this.planType, planId).subscribe({
      next: (planData) => {
        if (planData) {
          this.view!.applyRefreshedPlanData(planData);
        } else {
          this.view!.clearOptimizationLock();
        }
      },
      error: (error: HttpErrorResponse) => {
        this.showOperationError(extractHttpErrorMessage(error));
      }
    });
  }

  showOperationError(message?: string, technicalDetails?: string): void {
    if (!this.view) {
      throw new Error('GanttChartPresenter: view not set');
    }

    let text = this.formatErrorText(message);
    if (technicalDetails) {
      text = `${text} (${technicalDetails})`;
    }
    this.flashMessageService.show({ type: 'error', text });
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
