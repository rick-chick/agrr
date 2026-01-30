export type PlanOptimizingViewState = {
  status: string;
  progress: number;
};

export interface PlanOptimizingView {
  get control(): PlanOptimizingViewState;
  set control(value: PlanOptimizingViewState);
}
