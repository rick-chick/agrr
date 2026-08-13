import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { CreateTaskScheduleItemUseCase } from './create-task-schedule-item.usecase';
import { WorkRecordGateway } from './work-record-gateway';
import { CreateTaskScheduleItemOutputPort } from './create-task-schedule-item.output-port';

describe('CreateTaskScheduleItemUseCase', () => {
  const createFn = vi.fn(() =>
    of({
      item: {
        id: 99,
        name: 'Manual task',
        scheduled_date: '2026-07-10',
        status: 'planned',
        field_cultivation_id: 10
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
      createTaskScheduleItem: createFn,
      updateTaskScheduleItem: () => of({} as never)
    }) as WorkRecordGateway;

  it('calls gateway create and forwards success', () => {
    createFn.mockClear();
    const onSuccess = vi.fn();
    const outputPort: CreateTaskScheduleItemOutputPort = {
      onMutationSuccess: onSuccess,
      onMutationError: () => {}
    };
    const useCase = new CreateTaskScheduleItemUseCase(outputPort, gateway());
    const onDone = vi.fn();
    useCase.execute({
      planId: 5,
      body: {
        field_cultivation_id: 10,
        name: 'Manual task',
        scheduled_date: '2026-07-10'
      },
      onSuccess: onDone
    });

    expect(createFn).toHaveBeenCalledWith(5, {
      field_cultivation_id: 10,
      name: 'Manual task',
      scheduled_date: '2026-07-10'
    });
    expect(onSuccess).toHaveBeenCalled();
    expect(onDone).toHaveBeenCalled();
  });

  it('calls onError when gateway fails', () => {
    const failingGateway: WorkRecordGateway = {
      ...gateway(),
      createTaskScheduleItem: () => throwError(() => new Error('fail'))
    };
    const onError = vi.fn();
    const outputPort: CreateTaskScheduleItemOutputPort = {
      onMutationSuccess: () => {},
      onMutationError: onError
    };
    const useCase = new CreateTaskScheduleItemUseCase(outputPort, failingGateway);
    useCase.execute({
      planId: 5,
      body: {
        field_cultivation_id: 10,
        name: 'Manual task',
        scheduled_date: '2026-07-10'
      }
    });

    expect(onError).toHaveBeenCalled();
  });
});
