import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { PlanWorkRecordsView, PlanWorkRecordsViewState } from '../../components/plans/plan-work-records.view';
import { WorkRecord } from '../../models/plans/work-record';
import { LoadWorkRecordsDataDto } from '../../usecase/plans/load-work-records.dtos';
import { PlanWorkRecordsPresenter } from './plan-work-records.presenter';

function baseRecord(overrides: Partial<WorkRecord> = {}): WorkRecord {
  return {
    id: 1,
    cultivation_plan_id: 7,
    field_cultivation_id: 10,
    task_schedule_item_id: null,
    agricultural_task_id: null,
    name: 'Weeding',
    task_type: null,
    actual_date: '2026-06-12',
    amount: null,
    amount_unit: null,
    time_spent_minutes: null,
    notes: null,
    created_at: '2026-06-12',
    updated_at: '2026-06-12',
    task_schedule_item: null,
    ...overrides
  };
}

describe('PlanWorkRecordsPresenter', () => {
  let presenter: PlanWorkRecordsPresenter;
  let lastControl: PlanWorkRecordsViewState | null;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [PlanWorkRecordsPresenter]
    });
    presenter = TestBed.inject(PlanWorkRecordsPresenter);

    lastControl = null;
    const view: PlanWorkRecordsView = {
      get control(): PlanWorkRecordsViewState {
        return (
          lastControl ?? {
            loading: true,
            error: null,
            plan: null,
            groups: []
          }
        );
      },
      set control(value: PlanWorkRecordsViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('passes records without photos through to the view', () => {
    const dto: LoadWorkRecordsDataDto = {
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          records: [baseRecord()]
        }
      ]
    };

    presenter.present(dto);

    expect(lastControl?.groups[0]?.records[0]?.photos).toBeUndefined();
  });

  it('passes records with photos through to the view', () => {
    const photos = [
      {
        id: 11,
        work_record_id: 1,
        position: 0,
        content_type: 'image/jpeg',
        byte_size: 1024,
        url: '/api/v1/plans/7/work_records/1/photos/11/content',
        created_at: '2026-06-12T00:00:00Z'
      }
    ];
    const dto: LoadWorkRecordsDataDto = {
      plan: { id: 7, name: 'Field plan' },
      groups: [
        {
          monthLabel: '2026-06',
          records: [baseRecord({ photos })]
        }
      ]
    };

    presenter.present(dto);

    expect(lastControl?.groups[0]?.records[0]?.photos).toEqual(photos);
  });
});
