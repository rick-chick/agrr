import { OptimizationFailureCategory } from '../../services/ux-analytics.events';

export type PublicPlanOptimizingViewState = {
  status: string;
  progress: number;
  phaseMessage: string;
  /** User-facing hint for what to try next when status is failed. */
  failureHint?: string;
  /** Machine-readable failure category for analytics recovery events. */
  failureCategory?: OptimizationFailureCategory;
};

export interface PublicPlanOptimizingView {
  get control(): PublicPlanOptimizingViewState;
  set control(value: PublicPlanOptimizingViewState);
  /** Called by presenter when optimization status becomes 'completed'. */
  onOptimizationCompleted?(): void;
}
