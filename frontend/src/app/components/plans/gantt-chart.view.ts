import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PendingErrorFlashRequest } from '../../core/view-effects/pending-error-flash-view.effects';

export interface GanttChartViewControl {
  pendingErrorFlash: PendingErrorFlashRequest | null;
}

/** View callbacks for {@link GanttChartPresenter} (mutation outcome / refresh). */
export interface GanttChartView {
  control: GanttChartViewControl;
  applyRefreshedPlanData(planData: CultivationPlanData): void;
  applyBarResetPlanData(planData: CultivationPlanData): void;
  requestPlanRefresh(planId: number): void;
  updateChartOnly(): void;
  resetBarPosition(): void;
  clearOptimizationLock(): void;
  setFieldFormLoading(loading: boolean): void;
}
