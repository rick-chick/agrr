import { of } from 'rxjs';
import { describe, it, expect } from 'vitest';
import { LoadWorkRecordsUseCase, groupWorkRecordsByMonth } from './load-work-records.usecase';
import { WorkRecordGateway } from './work-record-gateway';
import { PlanGateway } from './plan-gateway';
import { LoadWorkRecordsOutputPort } from './load-work-records.output-port';
import { WorkRecord } from '../../models/plans/work-record';

const plan = {
  id: 1,
  name: 'Plan',
  status: 'active',
  planning_start_date: '2026-01-01',
  planning_end_date: '2026-12-31',
  timeline_generated_at: '2026-06-01',
  timeline_generated_at_display: '2026-06-01'
};

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
      deleteWorkRecord: () => of({ deleted: true }),
      skipTaskScheduleItem: () => of({ item: { id: 1, status: 'skipped', cancelled_at: null } }),
      unskipTaskScheduleItem: () => of({ item: { id: 1, status: 'planned', cancelled_at: null } })
    };
    const planGateway: PlanGateway = {
      listPlans: () => of([]),
      fetchPlan: () => of({ id: 1, name: 'Plan', status: 'active' }),
      fetchPlanData: () => of({} as never),
      getPublicPlanData: () => of({} as never),
      getTaskSchedule: () => of({} as never),
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
});
