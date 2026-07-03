import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { UpdateWorkRecordUseCase } from './update-work-record.usecase';
import { WorkRecordGateway } from './work-record-gateway';
import { UpdateWorkRecordOutputPort } from './update-work-record.output-port';
import { WorkRecord } from '../../models/plans/work-record';

describe('UpdateWorkRecordUseCase', () => {
  const sampleRecord: WorkRecord = {
    id: 1,
    cultivation_plan_id: 5,
    field_cultivation_id: 10,
    task_schedule_item_id: 123,
    agricultural_task_id: 2,
    name: '追肥',
    task_type: 'fertilizer',
    actual_date: '2026-06-12',
    amount: '1.5',
    amount_unit: 'kg',
    time_spent_minutes: null,
    notes: 'updated',
    created_at: '2026-06-12T00:00:00Z',
    updated_at: '2026-06-12T00:00:00Z',
    task_schedule_item: null
  };

  const gateway = (updateWorkRecord: WorkRecordGateway['updateWorkRecord']): WorkRecordGateway =>
    ({
      listWorkRecords: () => of({ work_records: [] }),
      createWorkRecord: () => of({ work_record: sampleRecord }),
      updateWorkRecord,
      deleteWorkRecord: () =>
        of({
          undo_token: 'stub',
          undo_path: '/undo_deletion?undo_token=stub',
          toast_message: 'stub',
          undo_deadline: '2026',
          auto_hide_after: 5000
        }),
      skipTaskScheduleItem: () => of({ item: { id: 1, status: 'skipped', cancelled_at: null } }),
      unskipTaskScheduleItem: () => of({ item: { id: 1, status: 'planned', cancelled_at: null } })
    }) as WorkRecordGateway;

  it('forwards success', () => {
    const onSuccess = vi.fn();
    const updateWorkRecord = vi.fn(() => of({ work_record: sampleRecord }));
    const outputPort: UpdateWorkRecordOutputPort = {
      onSuccess,
      onValidationError: () => {},
      onError: () => {}
    };

    new UpdateWorkRecordUseCase(outputPort, gateway(updateWorkRecord)).execute({
      planId: 5,
      workRecordId: 1,
      body: { notes: 'updated' }
    });

    expect(updateWorkRecord).toHaveBeenCalledWith(5, 1, { notes: 'updated' });
    expect(onSuccess).toHaveBeenCalledWith({ workRecord: sampleRecord });
  });

  it('maps 422 validation errors', () => {
    const onValidationError = vi.fn();
    const outputPort: UpdateWorkRecordOutputPort = {
      onSuccess: () => {},
      onValidationError,
      onError: () => {}
    };

    new UpdateWorkRecordUseCase(
      outputPort,
      gateway(() =>
        throwError(
          () =>
            new HttpErrorResponse({
              status: 422,
              error: { errors: { name: ['plans.work.errors.name_required'] } }
            })
        )
      )
    ).execute({ planId: 5, workRecordId: 1, body: { name: '' } });

    expect(onValidationError).toHaveBeenCalled();
  });
});
