import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { DeleteWorkRecordUseCase } from './delete-work-record.usecase';
import { WorkRecordGateway } from './work-record-gateway';
import { DeleteWorkRecordOutputPort } from './delete-work-record.output-port';

describe('DeleteWorkRecordUseCase', () => {
  const gateway = (deleteWorkRecord: WorkRecordGateway['deleteWorkRecord']): WorkRecordGateway =>
    ({
      listWorkRecords: () => of({ work_records: [] }),
      createWorkRecord: () => of({} as never),
      updateWorkRecord: () => of({} as never),
      deleteWorkRecord,
      skipTaskScheduleItem: () => of({ item: { id: 1, status: 'skipped', cancelled_at: null } }),
      unskipTaskScheduleItem: () => of({ item: { id: 1, status: 'planned', cancelled_at: null } })
    }) as WorkRecordGateway;

  it('calls gateway delete and onDeleteSuccess', () => {
    const onDeleteSuccess = vi.fn();
    const deleteWorkRecord = vi.fn(() => of({ deleted: true }));
    const outputPort: DeleteWorkRecordOutputPort = {
      onDeleteSuccess,
      onError: () => {}
    };

    new DeleteWorkRecordUseCase(outputPort, gateway(deleteWorkRecord)).execute({
      planId: 5,
      workRecordId: 9
    });

    expect(deleteWorkRecord).toHaveBeenCalledWith(5, 9);
    expect(onDeleteSuccess).toHaveBeenCalled();
  });

  it('calls onError when delete fails', () => {
    const onError = vi.fn();
    const outputPort: DeleteWorkRecordOutputPort = {
      onDeleteSuccess: () => {},
      onError
    };

    new DeleteWorkRecordUseCase(
      outputPort,
      gateway(() => throwError(() => new Error('fail')))
    ).execute({ planId: 5, workRecordId: 9 });

    expect(onError).toHaveBeenCalled();
  });
});
