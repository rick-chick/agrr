import { describe, it, expect, beforeEach, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { HttpErrorResponse } from '@angular/common/http';

import { GANTT_I18N_KEYS } from '../../core/i18n/gantt-locale.keys';
import { GanttChartPresenter } from './gantt-chart.presenter';
import { GanttChartView } from '../../components/plans/gantt-chart.view';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { GanttPlanCoordinatorService } from '../../services/plans/gantt-plan-coordinator.service';

describe('GanttChartPresenter', () => {
  let presenter: GanttChartPresenter;
  let view: GanttChartView;
  let translate: { instant: ReturnType<typeof vi.fn> };
  let coordinator: {
    loadPlanData: ReturnType<typeof vi.fn>;
  };
  let lastControl: GanttChartView['control'];

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
    lastControl = { pendingErrorFlash: null };
    view = {
      get control() {
        return lastControl;
      },
      set control(value) {
        lastControl = value;
      },
      applyRefreshedPlanData: vi.fn(),
      updateChartOnly: vi.fn(),
      resetBarPosition: vi.fn(),
      clearOptimizationLock: vi.fn(),
      setFieldFormLoading: vi.fn()
    };
    translate = {
      instant: vi.fn((key: string) => `t:${key}`)
    };
    coordinator = { loadPlanData: vi.fn() };

    presenter = new GanttChartPresenter(
      translate as never,
      coordinator as unknown as GanttPlanCoordinatorService
    );
    presenter.setView(view);
    presenter.bindPlanContext('private');
  });

  it('shows translated refetch_failed and updates chart when configured', () => {
    presenter.applyMutationOutcome(
      { status: 'failure', failure: { refetchFailed: true } },
      7,
      { onRefetchFailure: 'update_chart' }
    );

    expect(translate.instant).toHaveBeenCalledWith(GANTT_I18N_KEYS.js.logs.dataRefetchFailed);
    expect(lastControl.pendingErrorFlash).toEqual({
      type: 'error',
      text: `t:${GANTT_I18N_KEYS.js.logs.dataRefetchFailed}`
    });
    expect(view.updateChartOnly).toHaveBeenCalled();
    expect(view.clearOptimizationLock).toHaveBeenCalled();
  });

  it('reloads plan data on refetch_error by default', () => {
    coordinator.loadPlanData.mockReturnValue(of(planData()));

    presenter.applyMutationOutcome({ status: 'failure', failure: { refetchError: true } }, 7);

    expect(coordinator.loadPlanData).toHaveBeenCalledWith('private', 7);
    expect(view.applyRefreshedPlanData).toHaveBeenCalled();
  });

  it('shows API message and reverts bar on message failure', () => {
    presenter.applyMutationOutcome(
      { status: 'failure', failure: { message: 'bad request' } },
      7,
      { revertBarOnMessageFailure: true }
    );

    expect(lastControl.pendingErrorFlash).toEqual({
      type: 'error',
      text: 'bad request'
    });
    expect(view.resetBarPosition).toHaveBeenCalled();
  });

  it('applies refreshed plan data on success', () => {
    const data = planData();
    presenter.applyMutationOutcome({ status: 'success', data }, 7);

    expect(view.applyRefreshedPlanData).toHaveBeenCalledWith(data);
  });

  it('refreshPlanData applies data when coordinator returns plan', () => {
    const data = planData();
    coordinator.loadPlanData.mockReturnValue(of(data));

    presenter.refreshPlanData(7);

    expect(coordinator.loadPlanData).toHaveBeenCalledWith('private', 7);
    expect(view.applyRefreshedPlanData).toHaveBeenCalledWith(data);
  });

  it('refreshPlanData surfaces HTTP errors', () => {
    coordinator.loadPlanData.mockReturnValue(
      throwError(() => new HttpErrorResponse({ error: { message: 'network' }, status: 500 }))
    );

    presenter.refreshPlanData(7);

    expect(lastControl.pendingErrorFlash).toEqual({
      type: 'error',
      text: 'network'
    });
  });
});
