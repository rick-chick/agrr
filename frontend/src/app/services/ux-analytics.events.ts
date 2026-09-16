export const UX_OPTIMIZATION_LIFECYCLE_EVENT = 'ux_optimization_lifecycle';
export const UX_RECOVERY_ACTION_EVENT = 'ux_recovery_action';

export type OptimizationLifecyclePhase = 'started' | 'completed' | 'failed' | 'recovered';

export type OptimizationFlow = 'plans' | 'public_plans';

export type JobScenario = 'J3';

export type OptimizationFailureCategory =
  | 'timeout'
  | 'fetching_weather'
  | 'predicting_weather'
  | 'task_schedule_generation'
  | 'optimizing'
  | 'connection_lost'
  | 'default';

export type RecoveryAction = 'reload' | 'back_to_plan' | 'try_again' | 'start_over';

export type OptimizationLifecycleParams = {
  phase: OptimizationLifecyclePhase;
  flow: OptimizationFlow;
  job_scenario: JobScenario;
  failure_category?: OptimizationFailureCategory;
};

export type RecoveryActionParams = {
  recovery_action: RecoveryAction;
  failure_category: OptimizationFailureCategory;
  flow: OptimizationFlow;
};
