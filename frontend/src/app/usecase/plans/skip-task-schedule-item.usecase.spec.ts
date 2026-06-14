import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { SkipTaskScheduleItemUseCase } from './skip-task-schedule-item.usecase';
import { WorkRecordGateway } from './work-record-gateway';
import { SkipTaskScheduleItemOutputPort } from './skip-task-schedule-item.output-port';

describe('SkipTaskScheduleItemUseCase', () => {
  const skipFn = vi.fn(() => of({ item: { id: 1, status: 'skipped', cancelled_at: '2026-06-12' } }));
  const unskipFn = vi.fn(() => of({ item: { id: 1, status: 'planned', cancelled_at: null } }));

  const gateway = (): WorkRecordGateway =>
    ({
      listWorkRecords: () => of({ work_records: [] }),
      createWorkRecord: () => of({} as never),
      updateWorkRecord: () => of({} as never),
      deleteWorkRecord: () => of({ deleted: true }),
      skipTaskScheduleItem: skipFn,
      unskipTaskScheduleItem: unskipFn
    }) as WorkRecordGateway;

  it('calls skip when skip is true', () => {
    skipFn.mockClear();
    const onSuccess = vi.fn();
    const outputPort: SkipTaskScheduleItemOutputPort = {
      onSuccess,
      onError: () => {}
    };
    const useCase = new SkipTaskScheduleItemUseCase(outputPort, gateway());
    useCase.execute({ planId: 5, itemId: 1, skip: true });

    expect(skipFn).toHaveBeenCalledWith(5, 1);
    expect(onSuccess).toHaveBeenCalled();
  });

  it('calls unskip when skip is false', () => {
    unskipFn.mockClear();
    const onSuccess = vi.fn();
    const outputPort: SkipTaskScheduleItemOutputPort = {
      onSuccess,
      onError: () => {}
    };
    const useCase = new SkipTaskScheduleItemUseCase(outputPort, gateway());
    useCase.execute({ planId: 5, itemId: 1, skip: false });

    expect(unskipFn).toHaveBeenCalledWith(5, 1);
    expect(onSuccess).toHaveBeenCalled();
  });

  it('calls onError when gateway fails', () => {
    const failingGateway: WorkRecordGateway = {
      ...gateway(),
      skipTaskScheduleItem: () => throwError(() => new Error('fail'))
    };
    const onError = vi.fn();
    const outputPort: SkipTaskScheduleItemOutputPort = {
      onSuccess: () => {},
      onError
    };
    const useCase = new SkipTaskScheduleItemUseCase(outputPort, failingGateway);
    useCase.execute({ planId: 5, itemId: 1, skip: true });

    expect(onError).toHaveBeenCalled();
  });
});
