export type PlanOptimizingViewState = {
  status: string;
  progress: number;
  phaseMessage: string;
};

export interface PlanOptimizingView {
  get control(): PlanOptimizingViewState;
  set control(value: PlanOptimizingViewState);
  /** Called by presenter when optimization reaches completion (status or 100% progress). */
  onOptimizationCompleted?(): void;
}
