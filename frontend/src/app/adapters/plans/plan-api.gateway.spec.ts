import { of, throwError, firstValueFrom } from 'rxjs';
import { describe, it, expect, beforeEach, vi } from 'vitest';
import { PlanApiGateway } from './plan-api.gateway';
import { ApiClientService } from '../../services/api-client.service';
import { PlanSummary } from '../../domain/plans/plan-summary';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { TaskScheduleResponse } from '../../models/plans/task-schedule';
import { DeletionUndoResponse } from '../../domain/shared/deletion-undo-response';

describe('PlanApiGateway', () => {
  let apiClient: {
    get: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
  let gateway: PlanApiGateway;

  beforeEach(() => {
    apiClient = {
      get: vi.fn(),
      delete: vi.fn()
    };
    gateway = new PlanApiGateway(apiClient as unknown as ApiClientService);
  });

  describe('listPlans', () => {
    it('returns Observable<PlanSummary[]>', async () => {
      const plans: PlanSummary[] = [
        { id: 1, name: 'Plan 1', status: 'active' },
        { id: 2, name: 'Plan 2', status: 'completed' }
      ];
      vi.mocked(apiClient.get).mockReturnValue(of(plans));

      const result = await firstValueFrom(gateway.listPlans());
      expect(result).toEqual(plans);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/plans');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.listPlans())).rejects.toThrow('network error');
    });
  });

  describe('fetchPlan', () => {
    it('returns Observable<PlanSummary>', async () => {
      const plan: PlanSummary = { id: 7, name: 'Plan 7', status: 'active' };
      vi.mocked(apiClient.get).mockReturnValue(of(plan));

      const result = await firstValueFrom(gateway.fetchPlan(7));
      expect(result).toEqual(plan);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/plans/7');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.fetchPlan(7))).rejects.toThrow('network error');
    });
  });

  describe('fetchPlanData', () => {
    it('returns Observable<CultivationPlanData>', async () => {
      const planData: CultivationPlanData = {
        success: true,
        data: {
          id: 1,
          plan_year: 2025,
          plan_name: 'Plan 1',
          status: 'active',
          total_area: 42.2,
          planning_start_date: '2025-01-01',
          planning_end_date: '2025-12-31',
          fields: [
            {
              id: 100,
              field_id: 10,
              name: 'Field A',
              area: 12.5,
              daily_fixed_cost: 45
            }
          ],
          crops: [
            {
              id: 200,
              name: 'Crop A',
              area_per_unit: 1.8,
              revenue_per_area: 60
            }
          ],
          cultivations: [
            {
              id: 300,
              field_id: 100,
              field_name: 'Field A',
              crop_id: 200,
              crop_name: 'Crop A',
              area: 8.3,
              start_date: '2025-01-05',
              completion_date: '2025-02-10',
              cultivation_days: 36,
              estimated_cost: 1200,
              revenue: 1800,
              profit: 600,
              status: 'scheduled'
            }
          ]
        },
        total_profit: 1000,
        total_revenue: 2500,
        total_cost: 1500
      };
      vi.mocked(apiClient.get).mockReturnValue(of(planData));

      const result = await firstValueFrom(gateway.fetchPlanData(7));
      expect(result).toEqual(planData);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/plans/cultivation_plans/7/data');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.fetchPlanData(7))).rejects.toThrow('network error');
    });
  });

  describe('getPublicPlanData', () => {
    it('returns Observable<CultivationPlanData>', async () => {
      const planData: CultivationPlanData = {
        success: true,
        data: {
          id: 2,
          plan_year: 2024,
          plan_name: 'Public Plan 1',
          status: 'completed',
          total_area: 60.0,
          planning_start_date: '2024-01-01',
          planning_end_date: '2024-12-31',
          fields: [
            {
              id: 101,
              field_id: 11,
              name: 'Field B',
              area: 15.0,
              daily_fixed_cost: 50
            }
          ],
          crops: [
            {
              id: 201,
              name: 'Crop B',
              area_per_unit: 2.0,
              revenue_per_area: 70
            }
          ],
          cultivations: [
            {
              id: 301,
              field_id: 101,
              field_name: 'Field B',
              crop_id: 201,
              crop_name: 'Crop B',
              area: 10.0,
              start_date: '2024-03-01',
              completion_date: '2024-04-15',
              cultivation_days: 45,
              estimated_cost: 1500,
              revenue: 2100,
              profit: 600,
              status: 'completed'
            }
          ]
        },
        total_profit: 2000,
        total_revenue: 2500,
        total_cost: 500
      };
      vi.mocked(apiClient.get).mockReturnValue(of(planData));

      const result = await firstValueFrom(gateway.getPublicPlanData(7));
      expect(result).toEqual(planData);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/public_plans/cultivation_plans/7/data');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.getPublicPlanData(7))).rejects.toThrow('network error');
    });
  });

  describe('getTaskSchedule', () => {
    it('returns Observable<TaskScheduleResponse>', async () => {
      const taskSchedule: TaskScheduleResponse = {
        plan: {
          id: 7,
          name: 'Plan 7',
          status: 'active',
          planning_start_date: '2025-01-01',
          planning_end_date: '2025-12-31',
          timeline_generated_at: '2025-01-02T12:00:00Z',
          timeline_generated_at_display: 'Jan 2, 2025'
        },
        week: {
          start_date: '2025-01-01',
          end_date: '2025-01-07',
          label: 'Week 1',
          days: [
            { date: '2025-01-01', weekday: 'Wed', is_today: false }
          ]
        },
        milestones: [],
        fields: [
          {
            id: 5,
            name: 'Field Schedule A',
            crop_name: 'Crop A',
            area_sqm: 100,
            field_cultivation_id: 500,
            crop_id: 200,
            task_options: [],
            schedules: {
              general: [],
              fertilizer: [],
              unscheduled: []
            }
          }
        ],
        labels: {},
        minimap: {}
      };
      vi.mocked(apiClient.get).mockReturnValue(of(taskSchedule));

      const result = await firstValueFrom(gateway.getTaskSchedule(7));
      expect(result).toEqual(taskSchedule);
      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/plans/7/task_schedule');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.get).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.getTaskSchedule(7))).rejects.toThrow('network error');
    });
  });

  describe('deletePlan', () => {
    it('calls DELETE /api/v1/plans/:id and returns Observable<DeletionUndoResponse>', async () => {
      const response: DeletionUndoResponse = {
        undo_token: 'abc123',
        toast_message: 'プラン Foo を削除しました',
        undo_path: '/undo_deletion?undo_token=abc123',
        undo_deadline: '2026-02-03T12:00:00Z',
        resource: 'Foo',
        resource_dom_id: 'cultivation_plan_8',
        redirect_path: '/plans',
        auto_hide_after: 60000
      };
      vi.mocked(apiClient.delete).mockReturnValue(of(response));

      const result = await firstValueFrom(gateway.deletePlan(8));
      expect(result).toEqual(response);
      expect(apiClient.delete).toHaveBeenCalledWith('/api/v1/plans/8');
      expect(result.undo_token).toBe('abc123');
      expect(result.toast_message).toBe('プラン Foo を削除しました');
    });

    it('returns DeletionUndoResponse with minimal fields', async () => {
      const response: DeletionUndoResponse = {
        undo_token: 'token456',
        toast_message: 'Plan deleted',
        undo_path: '/undo_deletion?undo_token=token456'
      };
      vi.mocked(apiClient.delete).mockReturnValue(of(response));

      const result = await firstValueFrom(gateway.deletePlan(5));
      expect(result).toEqual(response);
      expect(apiClient.delete).toHaveBeenCalledWith('/api/v1/plans/5');
    });

    it('forwards error when api fails', async () => {
      vi.mocked(apiClient.delete).mockReturnValue(throwError(() => new Error('network error')));

      await expect(firstValueFrom(gateway.deletePlan(8))).rejects.toThrow('network error');
    });

    it('correctly interpolates planId in URL path', async () => {
      const response: DeletionUndoResponse = {
        undo_token: 'test',
        toast_message: 'Deleted',
        undo_path: '/undo_deletion?undo_token=test'
      };
      vi.mocked(apiClient.delete).mockReturnValue(of(response));

      await firstValueFrom(gateway.deletePlan(123));
      expect(apiClient.delete).toHaveBeenCalledWith('/api/v1/plans/123');
    });

    it('passes undo metadata required by toast undo contract', async () => {
      const response: DeletionUndoResponse = {
        undo_token: 'contract-token',
        toast_message: '契約に基づく削除です',
        undo_path: '/undo_deletion?undo_token=contract-token',
        undo_deadline: '2026-02-03T12:00:00Z',
        resource: 'Foo Contract',
        resource_dom_id: 'cultivation_plan_contract',
        redirect_path: '/plans',
        auto_hide_after: 45000
      };
      vi.mocked(apiClient.delete).mockReturnValue(of(response));

      const result = await firstValueFrom(gateway.deletePlan(10));
      expect(result).toEqual(response);
      expect(result.undo_deadline).toBe('2026-02-03T12:00:00Z');
      expect(result.resource).toBe('Foo Contract');
      expect(result.redirect_path).toBe('/plans');
      expect(result.auto_hide_after).toBe(45000);
      expect(apiClient.delete).toHaveBeenCalledWith('/api/v1/plans/10');
    });
  });
});
