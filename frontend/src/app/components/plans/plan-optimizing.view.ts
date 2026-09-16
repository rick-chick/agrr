import { OptimizationFailureCategory } from '../../services/ux-analytics.events';

export type PlanOptimizingViewState = {
  status: string;
  progress: number;
  phaseMessage: string;
  /** User-facing hint for what to try next when status is failed. */
  failureHint?: string;
  /** Machine-readable failure category for analytics recovery events. */
  failureCategory?: OptimizationFailureCategory;
};

export interface PlanOptimizingView {
  get control(): PlanOptimizingViewState;
  set control(value: PlanOptimizingViewState);
  /** Called by presenter when optimization reaches completion (status or 100% progress). */
  onOptimizationCompleted?(): void;
}
