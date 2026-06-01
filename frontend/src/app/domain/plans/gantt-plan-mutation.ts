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
