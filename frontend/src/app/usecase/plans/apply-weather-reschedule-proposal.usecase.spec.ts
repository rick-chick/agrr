import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import {
  ganttMutationCommandFailure,
  ganttMutationCommandSuccess
} from '../../domain/plans/gantt-plan-mutation';
import type { WeatherRescheduleAdjustMove } from '../../domain/plans/weather-reschedule-proposal-preview';
import { ApplyWeatherRescheduleProposalUseCase } from './apply-weather-reschedule-proposal.usecase';
import type { ApplyWeatherRescheduleProposalDataDto } from './apply-weather-reschedule-proposal.output-port';
import type { ApplyWeatherRescheduleProposalOutputPort } from './apply-weather-reschedule-proposal.output-port';
import type { GanttPlanGateway } from './gantt-plan-gateway';
import type { ErrorDto } from '../../domain/shared/error.dto';

const planData: CultivationPlanData = {
  success: true,
  data: {
    id: 7,
    plan_year: 2026,
    plan_name: 'Plan 7',
    status: 'active',
    total_area: 100,
    planning_start_date: '2026-01-01',
    planning_end_date: '2026-12-31',
    fields: [],
    crops: [],
    cultivations: []
  },
  total_profit: 0,
  total_revenue: 0,
  total_cost: 0
};

const moves: WeatherRescheduleAdjustMove[] = [
  {
    allocation_id: 10,
    action: 'move',
    to_field_id: 3,
    to_start_date: '2026-04-15'
  }
];

describe('ApplyWeatherRescheduleProposalUseCase', () => {
  let gateway: GanttPlanGateway;
  let outputPort: ApplyWeatherRescheduleProposalOutputPort;
  let present: ReturnType<typeof vi.fn<(dto: ApplyWeatherRescheduleProposalDataDto) => void>>;
  let onApplied: ReturnType<typeof vi.fn<() => void>>;
  let onError: ReturnType<typeof vi.fn<(dto: ErrorDto) => void>>;
  let useCase: ApplyWeatherRescheduleProposalUseCase;

  beforeEach(() => {
    present = vi.fn();
    onApplied = vi.fn();
    onError = vi.fn();
    outputPort = { present, onApplied, onError };

    gateway = {
      adjustPlanMoves: vi.fn(() => of(ganttMutationCommandSuccess())),
      loadPlanData: vi.fn(() => of(planData)),
      adjustCultivationMove: vi.fn(),
      addCrop: vi.fn(),
      removeCultivation: vi.fn(),
      addField: vi.fn(),
      removeField: vi.fn(),
      syncLandingDemoPlan: vi.fn()
    } as unknown as GanttPlanGateway;

    useCase = new ApplyWeatherRescheduleProposalUseCase(outputPort, gateway);
  });

  it('adjusts plan moves then presents reloaded plan data', () => {
    useCase.execute({ planId: 7, planType: 'private', moves });

    expect(gateway.adjustPlanMoves).toHaveBeenCalledWith({
      planType: 'private',
      planId: 7,
      moves
    });
    expect(gateway.loadPlanData).toHaveBeenCalledWith('private', 7);
    expect(onApplied).toHaveBeenCalledTimes(1);
    expect(present).toHaveBeenCalledWith({ planData });
    expect(onError).not.toHaveBeenCalled();
  });

  it('reports adjust failure without reloading plan data', () => {
    vi.mocked(gateway.adjustPlanMoves).mockReturnValue(
      of(ganttMutationCommandFailure('plans.errors.adjust_failed'))
    );

    useCase.execute({ planId: 7, planType: 'private', moves });

    expect(onError).toHaveBeenCalledWith({ message: 'plans.errors.adjust_failed' });
    expect(gateway.loadPlanData).not.toHaveBeenCalled();
    expect(onApplied).not.toHaveBeenCalled();
    expect(present).not.toHaveBeenCalled();
  });

  it('reports default adjust failure message when mutation returns success false without message', () => {
    vi.mocked(gateway.adjustPlanMoves).mockReturnValue(of({ success: false }));

    useCase.execute({ planId: 7, planType: 'private', moves });

    expect(onError).toHaveBeenCalledWith({ message: 'plans.errors.adjust_failed' });
  });

  it('reports load failure when reload returns null plan data', () => {
    vi.mocked(gateway.loadPlanData).mockReturnValue(of(null));

    useCase.execute({ planId: 7, planType: 'private', moves });

    expect(onApplied).toHaveBeenCalledTimes(1);
    expect(onError).toHaveBeenCalledWith({ message: 'plans.errors.load_failed' });
    expect(present).not.toHaveBeenCalled();
  });

  it('reports i18n key when adjustPlanMoves throws', () => {
    vi.mocked(gateway.adjustPlanMoves).mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 401, statusText: 'Unauthorized' }))
    );

    useCase.execute({ planId: 7, planType: 'private', moves });

    expect(onError).toHaveBeenCalledWith({ message: 'common.api_error.unauthorized' });
    expect(gateway.loadPlanData).not.toHaveBeenCalled();
    expect(onApplied).not.toHaveBeenCalled();
  });

  it('reports i18n key when loadPlanData throws after successful adjust', () => {
    vi.mocked(gateway.loadPlanData).mockReturnValue(
      throwError(() => new HttpErrorResponse({ status: 500, statusText: 'Server Error' }))
    );

    useCase.execute({ planId: 7, planType: 'private', moves });

    expect(onApplied).toHaveBeenCalledTimes(1);
    expect(onError).toHaveBeenCalledWith({ message: 'common.api_error.generic' });
    expect(present).not.toHaveBeenCalled();
  });
});
