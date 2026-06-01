import { describe, it, expect, beforeEach, vi } from 'vitest';
import { firstValueFrom, of, throwError } from 'rxjs';
import { HttpErrorResponse } from '@angular/common/http';

import { GanttPlanCoordinatorService } from './gantt-plan-coordinator.service';
import { PlanService } from './plan.service';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

describe('GanttPlanCoordinatorService', () => {
  let planService: {
    buildCultivationPlanEndpoint: ReturnType<typeof vi.fn>;
    adjustPlan: ReturnType<typeof vi.fn>;
    getPlanData: ReturnType<typeof vi.fn>;
    getPublicPlanData: ReturnType<typeof vi.fn>;
    addCrop: ReturnType<typeof vi.fn>;
    removeCultivation: ReturnType<typeof vi.fn>;
    addField: ReturnType<typeof vi.fn>;
    removeField: ReturnType<typeof vi.fn>;
  };
  let coordinator: GanttPlanCoordinatorService;

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
    planService = {
      buildCultivationPlanEndpoint: vi.fn(),
      adjustPlan: vi.fn(),
      getPlanData: vi.fn(),
      getPublicPlanData: vi.fn(),
      addCrop: vi.fn(),
      removeCultivation: vi.fn(),
      addField: vi.fn(),
      removeField: vi.fn()
    };
    coordinator = new GanttPlanCoordinatorService(planService as unknown as PlanService);
  });

  describe('adjustCultivationMove', () => {
    it('calls adjust and refetches private plan data', async () => {
      const refreshed = planData();
      planService.buildCultivationPlanEndpoint.mockReturnValue('/api/v1/plans/cultivation_plans/7/adjust');
      planService.adjustPlan.mockReturnValue(of({ success: true }));
      planService.getPlanData.mockReturnValue(of(refreshed));

      const outcome = await firstValueFrom(
        coordinator.adjustCultivationMove({
          planType: 'private',
          planId: 7,
          cultivationId: 14,
          toFieldId: 1,
          newStartDate: new Date('2026-09-15')
        })
      );

      expect(planService.buildCultivationPlanEndpoint).toHaveBeenCalledWith('private', 7, 'adjust');
      expect(planService.adjustPlan).toHaveBeenCalledWith('/api/v1/plans/cultivation_plans/7/adjust', {
        moves: [
          expect.objectContaining({
            allocation_id: 14,
            to_field_id: 1,
            action: 'move'
          })
        ]
      });
      expect(planService.getPlanData).toHaveBeenCalledWith(7);
      expect(outcome).toEqual({ status: 'success', data: refreshed });
    });

    it('calls adjust and refetches public plan data', async () => {
      const refreshed = planData();
      planService.buildCultivationPlanEndpoint.mockReturnValue(
        '/api/v1/public_plans/cultivation_plans/7/adjust'
      );
      planService.adjustPlan.mockReturnValue(of({ success: true }));
      planService.getPublicPlanData.mockReturnValue(of(refreshed));

      const outcome = await firstValueFrom(
        coordinator.adjustCultivationMove({
          planType: 'public',
          planId: 7,
          cultivationId: 14,
          toFieldId: 1,
          newStartDate: new Date('2026-09-15')
        })
      );

      expect(planService.getPublicPlanData).toHaveBeenCalledWith(7);
      expect(outcome).toEqual({ status: 'success', data: refreshed });
    });

    it('returns failure when adjust responds with an error message', async () => {
      planService.buildCultivationPlanEndpoint.mockReturnValue('/api/v1/plans/cultivation_plans/7/adjust');
      planService.adjustPlan.mockReturnValue(of({ success: false, message: 'bad request' }));

      const outcome = await firstValueFrom(
        coordinator.adjustCultivationMove({
          planType: 'private',
          planId: 7,
          cultivationId: 14,
          toFieldId: 1,
          newStartDate: new Date('2026-02-01')
        })
      );

      expect(outcome).toEqual({ status: 'failure', failure: { message: 'bad request' } });
      expect(planService.getPlanData).not.toHaveBeenCalled();
    });
  });

  describe('addCrop', () => {
    it('posts add_crop and refetches plan data', async () => {
      const refreshed = planData();
      planService.buildCultivationPlanEndpoint.mockReturnValue(
        '/api/v1/plans/cultivation_plans/7/add_crop'
      );
      planService.addCrop.mockReturnValue(of({ success: true }));
      planService.getPlanData.mockReturnValue(of(refreshed));

      const outcome = await firstValueFrom(
        coordinator.addCrop('private', 7, {
          crop_id: 99,
          display_start_date: '2026-02-01',
          display_end_date: '2026-08-31'
        })
      );

      expect(planService.addCrop).toHaveBeenCalledWith('/api/v1/plans/cultivation_plans/7/add_crop', {
        crop_id: 99,
        display_start_date: '2026-02-01',
        display_end_date: '2026-08-31'
      });
      expect(outcome).toEqual({ status: 'success', data: refreshed });
    });
  });

  describe('removeCultivation', () => {
    it('posts remove move and refetches plan data', async () => {
      const refreshed = planData();
      planService.buildCultivationPlanEndpoint.mockReturnValue(
        '/api/v1/plans/cultivation_plans/7/adjust'
      );
      planService.removeCultivation.mockReturnValue(of({ success: true }));
      planService.getPlanData.mockReturnValue(of(refreshed));

      const outcome = await firstValueFrom(coordinator.removeCultivation('private', 7, 33));

      expect(planService.removeCultivation).toHaveBeenCalledWith(
        '/api/v1/plans/cultivation_plans/7/adjust',
        { moves: [{ allocation_id: 33, action: 'remove' }] }
      );
      expect(outcome).toEqual({ status: 'success', data: refreshed });
    });
  });

  describe('addField', () => {
    it('posts add_field and refetches plan data', async () => {
      const refreshed = planData();
      planService.buildCultivationPlanEndpoint.mockReturnValue(
        '/api/v1/plans/cultivation_plans/7/add_field'
      );
      planService.addField.mockReturnValue(of({ success: true }));
      planService.getPlanData.mockReturnValue(of(refreshed));

      const outcome = await firstValueFrom(
        coordinator.addField('private', 7, { field_name: 'New Patch', field_area: 1.2 })
      );

      expect(planService.addField).toHaveBeenCalledWith('/api/v1/plans/cultivation_plans/7/add_field', {
        field_name: 'New Patch',
        field_area: 1.2
      });
      expect(outcome).toEqual({ status: 'success', data: refreshed });
    });
  });

  describe('removeField', () => {
    it('deletes field and refetches plan data', async () => {
      const refreshed = planData();
      planService.buildCultivationPlanEndpoint.mockReturnValue(
        '/api/v1/plans/cultivation_plans/7/remove_field/88'
      );
      planService.removeField.mockReturnValue(of({ success: true }));
      planService.getPlanData.mockReturnValue(of(refreshed));

      const outcome = await firstValueFrom(coordinator.removeField('private', 7, 88));

      expect(planService.removeField).toHaveBeenCalledWith(
        '/api/v1/plans/cultivation_plans/7/remove_field/88'
      );
      expect(outcome).toEqual({ status: 'success', data: refreshed });
    });
  });

  describe('loadPlanData', () => {
    it('returns null when refetch has no fields', async () => {
      planService.getPlanData.mockReturnValue(of({ data: { id: 7, fields: null } }));

      const result = await firstValueFrom(coordinator.loadPlanData('private', 7));

      expect(result).toBeNull();
    });
  });

  it('maps HttpErrorResponse to failure message on adjust', async () => {
    planService.buildCultivationPlanEndpoint.mockReturnValue('/api/v1/plans/cultivation_plans/7/adjust');
    planService.adjustPlan.mockReturnValue(
      throwError(() => new HttpErrorResponse({ error: { message: 'server error' }, status: 500 }))
    );

    const outcome = await firstValueFrom(
      coordinator.adjustCultivationMove({
        planType: 'private',
        planId: 7,
        cultivationId: 1,
        toFieldId: 1,
        newStartDate: new Date('2026-01-01')
      })
    );

    expect(outcome).toEqual({ status: 'failure', failure: { message: 'server error' } });
  });
});
