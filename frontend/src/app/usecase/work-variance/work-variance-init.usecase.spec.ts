import { describe, expect, it, vi } from 'vitest';
import { of, throwError } from 'rxjs';

import { WorkVarianceInitUseCase } from './work-variance-init.usecase';

describe('WorkVarianceInitUseCase', () => {
  it('presents grouped portfolio data and attention list', async () => {
    const rows = [
      {
        farmId: 1,
        farmName: 'Farm A',
        planId: 10,
        planYear: 2026,
        status: 'completed',
        unrecordedCount: 1,
        gddDelayCount: 0,
        thresholdExceededCount: 1,
        daysThresholdExceededCount: 1,
        carryoverNotImported: false
      }
    ];
    const outputPort = { present: vi.fn(), onError: vi.fn() };
    const workVarianceGateway = { listVariancePortfolio: vi.fn(() => of(rows)) };
    const planGateway = {
      getPlanVsActualSummary: vi.fn(() =>
        of({
          action_required_items: [
            {
              item_id: 1,
              field_cultivation_id: 1,
              category: 'general',
              name: '除草',
              scheduled_date: '2026-06-01',
              actual_date: '2026-06-08',
              delta_days: 7,
              gdd_trigger: 100,
              gdd_at_actual: 110,
              gdd_delta: 10,
              exceedance_kind: 'days'
            }
          ]
        })
      )
    };

    const useCase = new WorkVarianceInitUseCase(
      outputPort as never,
      workVarianceGateway as never,
      planGateway as never
    );
    useCase.execute();

    await vi.waitFor(() => expect(outputPort.present).toHaveBeenCalled());
    const dto = outputPort.present.mock.calls[0][0];
    expect(dto.farmGroups).toHaveLength(1);
    expect(dto.portfolioSummary.unrecordedCount).toBe(1);
    expect(dto.attentionList.items).toHaveLength(1);
  });

  it('re-applies filters without reloading gateway data', () => {
    const rows = [
      {
        farmId: 1,
        farmName: 'Farm A',
        planId: 10,
        planYear: 2026,
        status: 'completed',
        unrecordedCount: 0,
        gddDelayCount: 0,
        thresholdExceededCount: 0,
        daysThresholdExceededCount: 0,
        carryoverNotImported: false
      },
      {
        farmId: 2,
        farmName: 'Farm B',
        planId: 20,
        planYear: 2027,
        status: 'pending',
        unrecordedCount: 0,
        gddDelayCount: 0,
        thresholdExceededCount: 0,
        daysThresholdExceededCount: 0,
        carryoverNotImported: false
      }
    ];
    const outputPort = { present: vi.fn(), onError: vi.fn() };
    const workVarianceGateway = { listVariancePortfolio: vi.fn(() => of(rows)) };
    const planGateway = { getPlanVsActualSummary: vi.fn(() => of({ action_required_items: [] })) };

    const useCase = new WorkVarianceInitUseCase(
      outputPort as never,
      workVarianceGateway as never,
      planGateway as never
    );
    useCase.execute();
    useCase.applyFilters({ farmId: 2, status: null, planYear: null });

    expect(outputPort.present).toHaveBeenCalledTimes(2);
    const filteredDto = outputPort.present.mock.calls[1][0];
    expect(filteredDto.farmGroups).toHaveLength(1);
    expect(filteredDto.farmGroups[0]?.farmId).toBe(2);
    expect(workVarianceGateway.listVariancePortfolio).toHaveBeenCalledTimes(1);
  });

  it('reports API errors via output port', async () => {
    const outputPort = { present: vi.fn(), onError: vi.fn() };
    const workVarianceGateway = {
      listVariancePortfolio: vi.fn(() => throwError(() => new Error('api.errors.generic')))
    };

    const useCase = new WorkVarianceInitUseCase(
      outputPort as never,
      workVarianceGateway as never,
      { getPlanVsActualSummary: vi.fn() } as never
    );
    useCase.execute();

    await vi.waitFor(() => expect(outputPort.onError).toHaveBeenCalled());
    expect(outputPort.onError).toHaveBeenCalledWith({ message: 'api.errors.generic' });
  });
});
