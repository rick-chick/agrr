import { CultivationPlanData } from './cultivation-plan-data';

export type GanttPlanMutationCommandResult =
  | { success: true }
  | { success: false; message?: string };

export function ganttMutationCommandSuccess(): GanttPlanMutationCommandResult {
  return { success: true };
}

export function ganttMutationCommandFailure(message?: string): GanttPlanMutationCommandResult {
  return { success: false, message };
}

export type GanttPlanMutationFailure = {
  message?: string;
  refetchFailed?: boolean;
  refetchError?: boolean;
};

export type GanttPlanMutationFailureKind = 'refetch_failed' | 'refetch_error' | 'message';

export type GanttMutationFailureRecovery = 'refresh' | 'update_chart';

export type GanttPlanMutationFailureAction =
  | {
      kind: 'refetch_failed';
      recovery: GanttMutationFailureRecovery;
    }
  | {
      kind: 'refetch_error';
      recovery: GanttMutationFailureRecovery;
    }
  | {
      kind: 'message';
      message?: string;
      revertBar: boolean;
    };

export function classifyGanttPlanMutationFailure(
  failure: GanttPlanMutationFailure
): { kind: GanttPlanMutationFailureKind; message?: string } {
  if (failure.refetchFailed) {
    return { kind: 'refetch_failed' };
  }
  if (failure.refetchError) {
    return { kind: 'refetch_error' };
  }
  return { kind: 'message', message: failure.message };
}

export type GanttPlanMutationOutcome =
  | { status: 'success'; data: CultivationPlanData }
  | { status: 'failure'; failure: GanttPlanMutationFailure };

export function ganttMutationSuccess(data: CultivationPlanData): GanttPlanMutationOutcome {
  return { status: 'success', data };
}

export function ganttMutationFailure(failure: GanttPlanMutationFailure): GanttPlanMutationOutcome {
  return { status: 'failure', failure };
}

export function resolveGanttPlanMutationFailureAction(
  failure: GanttPlanMutationFailure,
  options: {
    onRefetchFailure?: GanttMutationFailureRecovery;
    revertBarOnMessageFailure?: boolean;
  } = {}
): GanttPlanMutationFailureAction {
  const classified = classifyGanttPlanMutationFailure(failure);
  const recovery = options.onRefetchFailure ?? 'refresh';

  switch (classified.kind) {
    case 'refetch_failed':
      return { kind: 'refetch_failed', recovery };
    case 'refetch_error':
      return { kind: 'refetch_error', recovery };
    case 'message':
      return {
        kind: 'message',
        message: classified.message,
        revertBar: options.revertBarOnMessageFailure ?? false
      };
  }
}
