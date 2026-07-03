import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import {
  ganttMutationCommandFailure,
  ganttMutationCommandSuccess,
  ganttMutationSuccess
} from '../../domain/plans/gantt-plan-mutation';
import { GanttPlanGateway } from './gantt-plan-gateway';
import { RunGanttPlanMutationOutputPort } from './run-gantt-plan-mutation.output-port';
import { RunGanttPlanMutationUseCase } from './run-gantt-plan-mutation.usecase';

describe('RunGanttPlanMutationUseCase', () => {
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

  it('runs mutation then refetches plan data on success', () => {
    const refreshed = planData();
    const gateway: Pick<GanttPlanGateway, 'adjustCultivationMove' | 'loadPlanData'> = {
      adjustCultivationMove: vi.fn(() => of(ganttMutationCommandSuccess())),
      loadPlanData: vi.fn(() => of(refreshed))
    };
    const outputPort: RunGanttPlanMutationOutputPort = {
      onMutationOutcome: vi.fn()
    };

    const useCase = new RunGanttPlanMutationUseCase(outputPort, gateway as GanttPlanGateway);
    const newStartDate = new Date('2026-02-01');
    useCase.execute({
      planType: 'private',
      planId: 7,
      command: {
        kind: 'adjustCultivationMove',
        cultivationId: 14,
        toFieldId: 2,
        newStartDate
      },
      presentation: { onRefetchFailure: 'update_chart' }
    });

    expect(gateway.adjustCultivationMove).toHaveBeenCalledWith({
      planType: 'private',
      planId: 7,
      cultivationId: 14,
      toFieldId: 2,
      newStartDate
    });
    expect(gateway.loadPlanData).toHaveBeenCalledWith('private', 7);
    expect(outputPort.onMutationOutcome).toHaveBeenCalledWith(ganttMutationSuccess(refreshed), {
      planId: 7,
      presentation: { onRefetchFailure: 'update_chart' }
    });
  });

  it('forwards mutation command failure without refetch', () => {
    const gateway: Pick<GanttPlanGateway, 'adjustCultivationMove' | 'loadPlanData'> = {
      adjustCultivationMove: vi.fn(() => of(ganttMutationCommandFailure('bad request'))),
      loadPlanData: vi.fn()
    };
    const outputPort: RunGanttPlanMutationOutputPort = {
      onMutationOutcome: vi.fn()
    };

    const useCase = new RunGanttPlanMutationUseCase(outputPort, gateway as GanttPlanGateway);
    useCase.execute({
      planType: 'private',
      planId: 7,
      command: {
        kind: 'adjustCultivationMove',
        cultivationId: 14,
        toFieldId: 2,
        newStartDate: new Date('2026-02-01')
      }
    });

    expect(gateway.loadPlanData).not.toHaveBeenCalled();
    expect(outputPort.onMutationOutcome).toHaveBeenCalledWith(
      { status: 'failure', failure: { message: 'bad request' } },
      { planId: 7, presentation: undefined }
    );
  });

  it('returns refetch_failed when loadPlanData yields empty data', () => {
    const gateway: Pick<GanttPlanGateway, 'removeField' | 'loadPlanData'> = {
      removeField: vi.fn(() => of(ganttMutationCommandSuccess())),
      loadPlanData: vi.fn(() => of(null))
    };
    const outputPort: RunGanttPlanMutationOutputPort = {
      onMutationOutcome: vi.fn()
    };

    const useCase = new RunGanttPlanMutationUseCase(outputPort, gateway as GanttPlanGateway);
    useCase.execute({
      planType: 'demo',
      planId: 1,
      command: { kind: 'removeField', fieldId: 88 }
    });

    expect(gateway.loadPlanData).toHaveBeenCalledWith('demo', 1);
    expect(outputPort.onMutationOutcome).toHaveBeenCalledWith(
      { status: 'failure', failure: { refetchFailed: true } },
      { planId: 1, presentation: undefined }
    );
  });

  it('returns refetch_error when loadPlanData throws', () => {
    const gateway: Pick<GanttPlanGateway, 'addCrop' | 'loadPlanData'> = {
      addCrop: vi.fn(() => of(ganttMutationCommandSuccess())),
      loadPlanData: vi.fn(() => throwError(() => new Error('network')))
    };
    const outputPort: RunGanttPlanMutationOutputPort = {
      onMutationOutcome: vi.fn()
    };

    const useCase = new RunGanttPlanMutationUseCase(outputPort, gateway as GanttPlanGateway);
    useCase.execute({
      planType: 'private',
      planId: 7,
      command: {
        kind: 'addCrop',
        payload: { crop_id: 3, display_start_date: '2026-03-01' }
      }
    });

    expect(outputPort.onMutationOutcome).toHaveBeenCalledWith(
      { status: 'failure', failure: { refetchError: true } },
      { planId: 7, presentation: undefined }
    );
  });

  it('delegates removeCultivation command to gateway', () => {
    const refreshed = planData();
    const gateway: Pick<GanttPlanGateway, 'removeCultivation' | 'loadPlanData'> = {
      removeCultivation: vi.fn(() => of(ganttMutationCommandSuccess())),
      loadPlanData: vi.fn(() => of(refreshed))
    };
    const outputPort: RunGanttPlanMutationOutputPort = {
      onMutationOutcome: vi.fn()
    };

    const useCase = new RunGanttPlanMutationUseCase(outputPort, gateway as GanttPlanGateway);
    useCase.execute({
      planType: 'public',
      planId: 42,
      command: { kind: 'removeCultivation', cultivationId: 99 }
    });

    expect(gateway.removeCultivation).toHaveBeenCalledWith('public', 42, 99);
    expect(outputPort.onMutationOutcome).toHaveBeenCalledWith(ganttMutationSuccess(refreshed), {
      planId: 42,
      presentation: undefined
    });
  });

  it('delegates addField command to gateway', () => {
    const refreshed = planData();
    const payload = { field_name: 'North', field_area: 1200, daily_fixed_cost: 50 };
    const gateway: Pick<GanttPlanGateway, 'addField' | 'loadPlanData'> = {
      addField: vi.fn(() => of(ganttMutationCommandSuccess())),
      loadPlanData: vi.fn(() => of(refreshed))
    };
    const outputPort: RunGanttPlanMutationOutputPort = {
      onMutationOutcome: vi.fn()
    };

    const useCase = new RunGanttPlanMutationUseCase(outputPort, gateway as GanttPlanGateway);
    useCase.execute({
      planType: 'private',
      planId: 7,
      command: { kind: 'addField', payload },
      presentation: { revertBarOnMessageFailure: true }
    });

    expect(gateway.addField).toHaveBeenCalledWith('private', 7, payload);
    expect(outputPort.onMutationOutcome).toHaveBeenCalledWith(ganttMutationSuccess(refreshed), {
      planId: 7,
      presentation: { revertBarOnMessageFailure: true }
    });
  });
});
