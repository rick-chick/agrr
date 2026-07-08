import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { LoadWorkRecordsUseCase, groupWorkRecordsByMonth } from './load-work-records.usecase';
import { WorkRecordGateway } from './work-record-gateway';
import { PlanGateway } from './plan-gateway';
import { LoadWorkRecordsOutputPort } from './load-work-records.output-port';
import { WorkRecord } from '../../models/plans/work-record';

function record(id: number, date: string): WorkRecord {
  return {
    id,
    cultivation_plan_id: 1,
    field_cultivation_id: 10,
    task_schedule_item_id: null,
    agricultural_task_id: null,
    name: `作業${id}`,
    task_type: null,
    actual_date: date,
    amount: null,
    amount_unit: null,
    time_spent_minutes: null,
    notes: null,
    created_at: '2026-06-01',
    updated_at: '2026-06-01',
    task_schedule_item: null
  };
}

describe('groupWorkRecordsByMonth', () => {
  it('groups records by year-month preserving date order within month', () => {
    const groups = groupWorkRecordsByMonth([
      record(1, '2026-06-12'),
      record(2, '2026-06-01'),
      record(3, '2026-05-28')
    ]);

    expect(groups).toHaveLength(2);
    expect(groups[0].monthLabel).toBe('2026-06');
    expect(groups[0].records.map((r) => r.id)).toEqual([1, 2]);
    expect(groups[1].monthLabel).toBe('2026-05');
  });
});

describe('LoadWorkRecordsUseCase', () => {
  it('loads records and plan name', () => {
    const gateway: WorkRecordGateway = {
      listWorkRecords: () =>
        of({ work_records: [record(1, '2026-06-12')] }),
      createWorkRecord: () => of({ work_record: record(1, '2026-06-12') }),
      updateWorkRecord: () => of({ work_record: record(1, '2026-06-12') }),
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
    };
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({ id: 1, name: 'Plan', status: 'active', farm_id: 1 }),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({} as never),
      regenerateTaskSchedule: () => of(undefined),
      deletePlan: () => of({} as never)
    };
    let result: Parameters<LoadWorkRecordsOutputPort['present']>[0] | null = null;
    const outputPort: LoadWorkRecordsOutputPort = {
      present: (dto) => {
        result = dto;
      },
      onError: () => {}
    };

    const useCase = new LoadWorkRecordsUseCase(outputPort, gateway, planGateway);
    useCase.execute({ planId: 1 });

    expect(result!.groups).toHaveLength(1);
    expect(result!.plan.name).toBe('Plan');
  });

  it('calls onError with i18n key when listWorkRecords fails with 404', () => {
    const gateway: WorkRecordGateway = {
      listWorkRecords: () =>
        throwError(() => new HttpErrorResponse({ status: 404, statusText: 'Not Found' })),
      createWorkRecord: () => of({ work_record: record(1, '2026-06-12') }),
      updateWorkRecord: () => of({ work_record: record(1, '2026-06-12') }),
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
    };
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({ id: 1, name: 'Plan', status: 'active', farm_id: 1 }),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({} as never),
      regenerateTaskSchedule: () => of(undefined),
      deletePlan: () => of({} as never)
    };
    const onError = vi.fn();
    const outputPort: LoadWorkRecordsOutputPort = {
      present: () => {},
      onError
    };

    const useCase = new LoadWorkRecordsUseCase(outputPort, gateway, planGateway);
    useCase.execute({ planId: 1 });

    expect(onError).toHaveBeenCalledWith({ message: 'common.api_error.not_found' });
  });
});
