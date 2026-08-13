import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { UpdateTaskScheduleItemUseCase } from './update-task-schedule-item.usecase';
import { WorkRecordGateway } from './work-record-gateway';
import { UpdateTaskScheduleItemOutputPort } from './update-task-schedule-item.output-port';

describe('UpdateTaskScheduleItemUseCase', () => {
  const updateFn = vi.fn(() =>
    of({
      item: {
        id: 123,
        name: 'Weeding',
        scheduled_date: '2026-07-15',
        status: 'rescheduled',
        field_cultivation_id: 10,
        rescheduled_at: '2026-06-12T00:00:00Z'
      }
    })
  );

  const gateway = (): WorkRecordGateway =>
    ({
      listWorkRecords: () => of({ work_records: [] }),
      createWorkRecord: () => of({} as never),
      updateWorkRecord: () => of({} as never),
      deleteWorkRecord: () =>
        of({
          undo_token: 'stub',
          undo_path: '/undo_deletion?undo_token=stub',
          toast_message: 'stub',
          undo_deadline: '2026',
          auto_hide_after: 5000
        }),
      skipTaskScheduleItem: () => of({ item: { id: 1, status: 'skipped', cancelled_at: null } }),
      unskipTaskScheduleItem: () => of({ item: { id: 1, status: 'planned', cancelled_at: null } }),
      createTaskScheduleItem: () => of({} as never),
      updateTaskScheduleItem: updateFn
    }) as WorkRecordGateway;

  it('calls gateway update and forwards success', () => {
    updateFn.mockClear();
    const onSuccess = vi.fn();
    const outputPort: UpdateTaskScheduleItemOutputPort = {
      onMutationSuccess: onSuccess,
      onMutationError: () => {}
    };
    const useCase = new UpdateTaskScheduleItemUseCase(outputPort, gateway());
    const onDone = vi.fn();
    useCase.execute({
      planId: 5,
      itemId: 123,
      body: { scheduled_date: '2026-07-15' },
      onSuccess: onDone
    });

    expect(updateFn).toHaveBeenCalledWith(5, 123, { scheduled_date: '2026-07-15' });
    expect(onSuccess).toHaveBeenCalled();
    expect(onDone).toHaveBeenCalled();
  });

  it('calls onError when gateway fails', () => {
    const failingGateway: WorkRecordGateway = {
      ...gateway(),
      updateTaskScheduleItem: () => throwError(() => new Error('fail'))
    };
    const onError = vi.fn();
    const outputPort: UpdateTaskScheduleItemOutputPort = {
      onMutationSuccess: () => {},
      onMutationError: onError
    };
    const useCase = new UpdateTaskScheduleItemUseCase(outputPort, failingGateway);
    useCase.execute({
      planId: 5,
      itemId: 123,
      body: { scheduled_date: '2026-07-15' }
    });

    expect(onError).toHaveBeenCalled();
  });
});
