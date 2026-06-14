import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { CreateWorkRecordUseCase } from './create-work-record.usecase';
import { WorkRecordGateway } from './work-record-gateway';
import { CreateWorkRecordOutputPort } from './create-work-record.output-port';
import { WorkRecord } from '../../models/plans/work-record';

describe('CreateWorkRecordUseCase', () => {
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
    notes: null,
    created_at: '2026-06-12T00:00:00Z',
    updated_at: '2026-06-12T00:00:00Z',
    task_schedule_item: { id: 123, name: '追肥', scheduled_date: '2026-06-12' }
  };

  const createGateway = (
    createWorkRecord: WorkRecordGateway['createWorkRecord']
  ): WorkRecordGateway =>
    ({
      listWorkRecords: () => of({ work_records: [] }),
      createWorkRecord,
      updateWorkRecord: () => of({ work_record: sampleRecord }),
      deleteWorkRecord: () => of({ deleted: true }),
      skipTaskScheduleItem: () => of({ item: { id: 1, status: 'skipped', cancelled_at: null } }),
      unskipTaskScheduleItem: () => of({ item: { id: 1, status: 'planned', cancelled_at: null } })
    }) as WorkRecordGateway;

  it('calls gateway and forwards success', () => {
    const onSuccess = vi.fn();
    const createWorkRecord = vi.fn(() => of({ work_record: sampleRecord }));
    const outputPort: CreateWorkRecordOutputPort = {
      onSuccess,
      onValidationError: () => {},
      onError: () => {}
    };

    const useCase = new CreateWorkRecordUseCase(outputPort, createGateway(createWorkRecord));
    const onDone = vi.fn();
    useCase.execute({
      planId: 5,
      body: { task_schedule_item_id: 123, actual_date: '2026-06-12' },
      onSuccess: onDone
    });

    expect(createWorkRecord).toHaveBeenCalledWith(5, {
      task_schedule_item_id: 123,
      actual_date: '2026-06-12'
    });
    expect(onSuccess).toHaveBeenCalledWith({ workRecord: sampleRecord });
    expect(onDone).toHaveBeenCalled();
  });

  it('maps 422 field errors to onValidationError', () => {
    const onValidationError = vi.fn();
    const error = new HttpErrorResponse({
      status: 422,
      error: { errors: { name: ['plans.work.errors.name_required'] } }
    });
    const outputPort: CreateWorkRecordOutputPort = {
      onSuccess: () => {},
      onValidationError,
      onError: () => {}
    };

    const useCase = new CreateWorkRecordUseCase(
      outputPort,
      createGateway(() => throwError(() => error))
    );
    useCase.execute({ planId: 5, body: { name: '', actual_date: '2026-06-12' } });

    expect(onValidationError).toHaveBeenCalledWith({
      fieldErrors: { name: ['plans.work.errors.name_required'] }
    });
  });

  it('calls onError for non-validation failures', () => {
    const onError = vi.fn();
    const outputPort: CreateWorkRecordOutputPort = {
      onSuccess: () => {},
      onValidationError: () => {},
      onError
    };

    const useCase = new CreateWorkRecordUseCase(
      outputPort,
      createGateway(() => throwError(() => new HttpErrorResponse({ status: 500 })))
    );
    useCase.execute({ planId: 5, body: { name: 'x', actual_date: '2026-06-12' } });

    expect(onError).toHaveBeenCalled();
  });
});
