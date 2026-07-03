import { describe, it, expect, beforeEach, vi } from 'vitest';
import { firstValueFrom, of, throwError } from 'rxjs';
import { HttpErrorResponse } from '@angular/common/http';

import { GanttPlanApiGateway } from './gantt-plan-api.gateway';
import { ApiService } from '../../services/api.service';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { LANDING_DEMO_PLAN_ID } from '../../domain/plans/cultivation-plan-context-type';
import { LANDING_DEMO_LABELS_FIXTURE } from '../../domain/plans/landing-demo-i18n.keys';
import { ganttMutationCommandSuccess } from '../../domain/plans/gantt-plan-mutation';

describe('GanttPlanApiGateway', () => {
  let apiClient: {
    get: ReturnType<typeof vi.fn>;
    post: ReturnType<typeof vi.fn>;
    delete: ReturnType<typeof vi.fn>;
  };
  let gateway: GanttPlanApiGateway;

  const planData = (): CultivationPlanData =>
    ({
      data: {
        id: 7,
        planning_start_date: '2026-01-01',
        planning_end_date: '2026-12-31',
        fields: [{ id: 1, name: 'Field 1' }],
        cultivations: []
      }
    }) as CultivationPlanData;

  beforeEach(() => {
    apiClient = {
      get: vi.fn(),
      post: vi.fn(),
      delete: vi.fn()
    };
    gateway = new GanttPlanApiGateway(apiClient as unknown as ApiService);
  });

  describe('syncLandingDemoPlan', () => {
    it('throws because demo sync is not supported by API gateway', async () => {
      await expect(
        firstValueFrom(gateway.syncLandingDemoPlan(LANDING_DEMO_LABELS_FIXTURE))
      ).rejects.toThrow('demo-only');
      expect(apiClient.get).not.toHaveBeenCalled();
    });
  });

  describe('adjustCultivationMove', () => {
    it('posts adjust for private plan without refetching', async () => {
      apiClient.post.mockReturnValue(of({ success: true }));

      const result = await firstValueFrom(
        gateway.adjustCultivationMove({
          planType: 'private',
          planId: 7,
          cultivationId: 14,
          toFieldId: 1,
          newStartDate: new Date('2026-09-15')
        })
      );

      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/plans/cultivation_plans/7/adjust', {
        moves: [
          expect.objectContaining({
            allocation_id: 14,
            to_field_id: 1,
            action: 'move'
          })
        ]
      });
      expect(apiClient.get).not.toHaveBeenCalled();
      expect(result).toEqual(ganttMutationCommandSuccess());
    });

    it('posts adjust for public plan without refetching', async () => {
      apiClient.post.mockReturnValue(of({ success: true }));

      const result = await firstValueFrom(
        gateway.adjustCultivationMove({
          planType: 'public',
          planId: 7,
          cultivationId: 14,
          toFieldId: 1,
          newStartDate: new Date('2026-09-15')
        })
      );

      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/public_plans/cultivation_plans/7/adjust', {
        moves: [
          expect.objectContaining({
            allocation_id: 14,
            to_field_id: 1,
            action: 'move'
          })
        ]
      });
      expect(apiClient.get).not.toHaveBeenCalled();
      expect(result).toEqual(ganttMutationCommandSuccess());
    });

    it('returns command failure when adjust responds with an error message', async () => {
      apiClient.post.mockReturnValue(of({ success: false, message: 'bad request' }));

      const result = await firstValueFrom(
        gateway.adjustCultivationMove({
          planType: 'private',
          planId: 7,
          cultivationId: 14,
          toFieldId: 1,
          newStartDate: new Date('2026-02-01')
        })
      );

      expect(result).toEqual({ success: false, message: 'bad request' });
      expect(apiClient.get).not.toHaveBeenCalled();
    });
  });

  describe('addCrop', () => {
    it('posts add_crop without refetching', async () => {
      apiClient.post.mockReturnValue(of({ success: true }));

      const result = await firstValueFrom(
        gateway.addCrop('private', 7, {
          crop_id: 99,
          display_start_date: '2026-02-01',
          display_end_date: '2026-08-31'
        })
      );

      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/plans/cultivation_plans/7/add_crop', {
        crop_id: 99,
        display_start_date: '2026-02-01',
        display_end_date: '2026-08-31'
      });
      expect(apiClient.get).not.toHaveBeenCalled();
      expect(result).toEqual(ganttMutationCommandSuccess());
    });
  });

  describe('removeCultivation', () => {
    it('posts remove move without refetching', async () => {
      apiClient.post.mockReturnValue(of({ success: true }));

      const result = await firstValueFrom(gateway.removeCultivation('private', 7, 33));

      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/plans/cultivation_plans/7/adjust', {
        moves: [{ allocation_id: 33, action: 'remove' }]
      });
      expect(apiClient.get).not.toHaveBeenCalled();
      expect(result).toEqual(ganttMutationCommandSuccess());
    });
  });

  describe('addField', () => {
    it('posts add_field without refetching', async () => {
      apiClient.post.mockReturnValue(of({ success: true }));

      const result = await firstValueFrom(
        gateway.addField('private', 7, { field_name: 'New Patch', field_area: 1.2 })
      );

      expect(apiClient.post).toHaveBeenCalledWith('/api/v1/plans/cultivation_plans/7/add_field', {
        field_name: 'New Patch',
        field_area: 1.2
      });
      expect(apiClient.get).not.toHaveBeenCalled();
      expect(result).toEqual(ganttMutationCommandSuccess());
    });
  });

  describe('removeField', () => {
    it('deletes field without refetching', async () => {
      apiClient.delete.mockReturnValue(of({ success: true }));

      const result = await firstValueFrom(gateway.removeField('private', 7, 88));

      expect(apiClient.delete).toHaveBeenCalledWith(
        '/api/v1/plans/cultivation_plans/7/remove_field/88'
      );
      expect(apiClient.get).not.toHaveBeenCalled();
      expect(result).toEqual(ganttMutationCommandSuccess());
    });
  });

  describe('loadPlanData', () => {
    it('throws for demo planType without calling HTTP', async () => {
      await expect(
        firstValueFrom(gateway.loadPlanData('demo', LANDING_DEMO_PLAN_ID))
      ).rejects.toThrow('demo plan type is not supported by API gateway');
      expect(apiClient.get).not.toHaveBeenCalled();
    });

    it('returns null when response has no fields', async () => {
      apiClient.get.mockReturnValue(of({ data: { id: 7, fields: null } }));

      const result = await firstValueFrom(gateway.loadPlanData('private', 7));

      expect(result).toBeNull();
    });

    it('returns plan data for private plans', async () => {
      const refreshed = planData();
      apiClient.get.mockReturnValue(of(refreshed));

      const result = await firstValueFrom(gateway.loadPlanData('private', 7));

      expect(apiClient.get).toHaveBeenCalledWith('/api/v1/plans/cultivation_plans/7/data');
      expect(result).toEqual(refreshed);
    });

    it('propagates HttpErrorResponse instead of swallowing to null', async () => {
      apiClient.get.mockReturnValue(
        throwError(() => new HttpErrorResponse({ error: { message: 'server error' }, status: 500 }))
      );

      await expect(firstValueFrom(gateway.loadPlanData('private', 7))).rejects.toBeInstanceOf(
        HttpErrorResponse
      );
    });
  });

  it('maps HttpErrorResponse to command failure on adjust', async () => {
    apiClient.post.mockReturnValue(
      throwError(() => new HttpErrorResponse({ error: { message: 'server error' }, status: 500 }))
    );

    const result = await firstValueFrom(
      gateway.adjustCultivationMove({
        planType: 'private',
        planId: 7,
        cultivationId: 1,
        toFieldId: 1,
        newStartDate: new Date('2026-01-01')
      })
    );

    expect(result).toEqual({ success: false, message: 'server error' });
  });
});
