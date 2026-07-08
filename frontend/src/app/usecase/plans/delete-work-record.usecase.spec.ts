import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { DeleteWorkRecordUseCase } from './delete-work-record.usecase';
import { WorkRecordGateway } from './work-record-gateway';
import { DeleteWorkRecordOutputPort } from './delete-work-record.output-port';

const undoResponse = {
  undo_token: 'token123',
  undo_path: '/undo_deletion?undo_token=token123',
  toast_message: 'plans.work_records.undo.toast:除草',
  undo_deadline: '2026-02-03T12:00:00Z',
  auto_hide_after: 5000
};

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

  it('calls gateway delete and onDeleteSuccess with undo payload', () => {
    const onDeleteSuccess = vi.fn();
    const deleteWorkRecord = vi.fn(() => of(undoResponse));
    const outputPort: DeleteWorkRecordOutputPort = {
      onDeleteSuccess,
      onError: () => {}
    };

    new DeleteWorkRecordUseCase(outputPort, gateway(deleteWorkRecord)).execute({
      planId: 5,
      workRecordId: 9
    });

    expect(deleteWorkRecord).toHaveBeenCalledWith(5, 9);
    expect(onDeleteSuccess).toHaveBeenCalledWith({ undo: undoResponse });
  });

  it('calls onError when undo payload is missing', () => {
    const onError = vi.fn();
    const outputPort: DeleteWorkRecordOutputPort = {
      onDeleteSuccess: () => {},
      onError
    };

    new DeleteWorkRecordUseCase(
      outputPort,
      gateway(() => of({ deleted: true } as never))
    ).execute({ planId: 5, workRecordId: 9 });

    expect(onError).toHaveBeenCalledWith({ message: 'deletion_undo.restore_failed' });
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
