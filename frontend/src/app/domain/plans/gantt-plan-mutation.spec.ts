import { describe, it, expect } from 'vitest';

import {
  classifyGanttPlanMutationFailure,
  resolveGanttPlanMutationFailureAction
} from './gantt-plan-mutation';

describe('gantt-plan-mutation', () => {
  it('classifyGanttPlanMutationFailure maps coordinator failure flags', () => {
    expect(classifyGanttPlanMutationFailure({ refetchFailed: true })).toEqual({
      kind: 'refetch_failed'
    });
    expect(classifyGanttPlanMutationFailure({ refetchError: true })).toEqual({
      kind: 'refetch_error'
    });
    expect(classifyGanttPlanMutationFailure({ message: 'bad request' })).toEqual({
      kind: 'message',
      message: 'bad request'
    });
  });

  it('resolveGanttPlanMutationFailureAction maps failures without presentation keys', () => {
    expect(
      resolveGanttPlanMutationFailureAction(
        { refetchFailed: true },
        { onRefetchFailure: 'update_chart' }
      )
    ).toEqual({
      kind: 'refetch_failed',
      recovery: 'update_chart'
    });

    expect(resolveGanttPlanMutationFailureAction({ refetchError: true }, {})).toEqual({
      kind: 'refetch_error',
      recovery: 'refresh'
    });

    expect(
      resolveGanttPlanMutationFailureAction(
        { message: 'bad request' },
        { revertBarOnMessageFailure: true }
      )
    ).toEqual({
      kind: 'message',
      message: 'bad request',
      revertBar: true
    });
  });
});
