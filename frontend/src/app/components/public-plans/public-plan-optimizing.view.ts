export type PublicPlanOptimizingViewState = {
  status: string;
  progress: number;
  phaseMessage: string;
};

export interface PublicPlanOptimizingView {
  get control(): PublicPlanOptimizingViewState;
  set control(value: PublicPlanOptimizingViewState);
  /** Called by presenter when optimization status becomes 'completed'. */
  onOptimizationCompleted?(): void;
}
