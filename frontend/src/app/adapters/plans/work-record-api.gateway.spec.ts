import { of, throwError, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { WorkRecordApiGateway } from './work-record-api.gateway';
import { ApiService } from '../../services/api.service';
import { WorkRecord } from '../../models/plans/work-record';

describe('WorkRecordApiGateway', () => {
  let apiClient: {
    get: ReturnType<typeof vi.fn>;
    post: ReturnType<typeof vi.fn>;
    patch: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
  let gateway: WorkRecordApiGateway;

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

  beforeEach(() => {
    apiClient = {
      get: vi.fn(),
      post: vi.fn(),
      patch: vi.fn(),
      delete: vi.fn()
    };
    gateway = new WorkRecordApiGateway(apiClient as unknown as ApiService);
  });

  it('lists work records', async () => {
    vi.mocked(apiClient.get).mockReturnValue(of({ work_records: [sampleRecord] }));

    const result = await firstValueFrom(gateway.listWorkRecords(5, { from: '2026-06-01' }));
    expect(result.work_records).toHaveLength(1);
    expect(apiClient.get).toHaveBeenCalledWith('/api/v1/plans/5/work_records?from=2026-06-01');
  });

  it('creates work record', async () => {
    vi.mocked(apiClient.post).mockReturnValue(of({ work_record: sampleRecord }));

    const result = await firstValueFrom(
      gateway.createWorkRecord(5, { task_schedule_item_id: 123, actual_date: '2026-06-12' })
    );
    expect(result.work_record.id).toBe(1);
    expect(apiClient.post).toHaveBeenCalledWith('/api/v1/plans/5/work_records', {
      work_record: { task_schedule_item_id: 123, actual_date: '2026-06-12' }
    });
  });

  it('updates work record', async () => {
    vi.mocked(apiClient.patch).mockReturnValue(of({ work_record: { ...sampleRecord, notes: 'updated' } }));

    const result = await firstValueFrom(gateway.updateWorkRecord(5, 1, { notes: 'updated' }));
    expect(result.work_record.notes).toBe('updated');
    expect(apiClient.patch).toHaveBeenCalledWith('/api/v1/plans/5/work_records/1', {
      work_record: { notes: 'updated' }
    });
  });

  it('deletes work record', async () => {
    vi.mocked(apiClient.delete).mockReturnValue(of({ deleted: true }));

    const result = await firstValueFrom(gateway.deleteWorkRecord(5, 1));
    expect(result.deleted).toBe(true);
    expect(apiClient.delete).toHaveBeenCalledWith('/api/v1/plans/5/work_records/1');
  });

  it('skips task schedule item', async () => {
    vi.mocked(apiClient.patch).mockReturnValue(
      of({ item: { id: 123, status: 'skipped', cancelled_at: '2026-06-12T00:00:00Z' } })
    );

    const result = await firstValueFrom(gateway.skipTaskScheduleItem(5, 123));
    expect(result.item.status).toBe('skipped');
    expect(apiClient.patch).toHaveBeenCalledWith('/api/v1/plans/5/task_schedule/items/123/skip', {});
  });

  it('forwards errors on create', async () => {
    vi.mocked(apiClient.post).mockReturnValue(throwError(() => new Error('network error')));

    await expect(
      firstValueFrom(gateway.createWorkRecord(5, { name: 'x', actual_date: '2026-06-12' }))
    ).rejects.toThrow('network error');
  });
});
