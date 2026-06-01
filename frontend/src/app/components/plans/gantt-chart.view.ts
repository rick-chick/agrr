import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

/** View callbacks for {@link GanttChartPresenter} (mutation outcome / refresh). */
export interface GanttChartView {
  applyRefreshedPlanData(planData: CultivationPlanData): void;
  updateChartOnly(): void;
  resetBarPosition(): void;
  clearOptimizationLock(): void;
  setFieldFormLoading(loading: boolean): void;
}
