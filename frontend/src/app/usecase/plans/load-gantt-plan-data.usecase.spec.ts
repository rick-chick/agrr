import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { GanttPlanGateway } from './gantt-plan-gateway';
import { LoadGanttPlanDataOutputPort } from './load-gantt-plan-data.output-port';
import { LoadGanttPlanDataUseCase } from './load-gantt-plan-data.usecase';

describe('LoadGanttPlanDataUseCase', () => {
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

  it('calls onPlanDataLoaded when gateway returns plan data', () => {
    const gateway: Pick<GanttPlanGateway, 'loadPlanData'> = {
      loadPlanData: vi.fn(() => of(planData()))
    };
    const outputPort: LoadGanttPlanDataOutputPort = {
      onPlanDataLoaded: vi.fn(),
      onPlanDataEmpty: vi.fn(),
      onLoadError: vi.fn()
    };

    const useCase = new LoadGanttPlanDataUseCase(outputPort, gateway as GanttPlanGateway);
    useCase.execute({ planType: 'private', planId: 7, purpose: 'refresh' });

    expect(gateway.loadPlanData).toHaveBeenCalledWith('private', 7);
    expect(outputPort.onPlanDataLoaded).toHaveBeenCalledWith({
      data: planData(),
      purpose: 'refresh'
    });
  });

  it('calls onPlanDataEmpty when gateway returns null', () => {
    const gateway: Pick<GanttPlanGateway, 'loadPlanData'> = {
      loadPlanData: vi.fn(() => of(null))
    };
    const outputPort: LoadGanttPlanDataOutputPort = {
      onPlanDataLoaded: vi.fn(),
      onPlanDataEmpty: vi.fn(),
      onLoadError: vi.fn()
    };

    const useCase = new LoadGanttPlanDataUseCase(outputPort, gateway as GanttPlanGateway);
    useCase.execute({ planType: 'public', planId: 9, purpose: 'reset_bar' });

    expect(outputPort.onPlanDataEmpty).toHaveBeenCalledWith({ purpose: 'reset_bar' });
  });

  it('calls onLoadError when gateway errors', () => {
    const gateway: Pick<GanttPlanGateway, 'loadPlanData'> = {
      loadPlanData: vi.fn(() =>
        throwError(() => new HttpErrorResponse({ error: { message: 'network' }, status: 500 }))
      )
    };
    const outputPort: LoadGanttPlanDataOutputPort = {
      onPlanDataLoaded: vi.fn(),
      onPlanDataEmpty: vi.fn(),
      onLoadError: vi.fn()
    };

    const useCase = new LoadGanttPlanDataUseCase(outputPort, gateway as GanttPlanGateway);
    useCase.execute({ planType: 'private', planId: 7, purpose: 'refresh' });

    expect(outputPort.onLoadError).toHaveBeenCalledWith({
      message: 'common.api_error.generic',
      purpose: 'refresh'
    });
  });
});
