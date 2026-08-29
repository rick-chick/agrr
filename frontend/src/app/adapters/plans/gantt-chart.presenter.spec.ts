import { describe, it, expect, beforeEach, vi } from 'vitest';

import { GANTT_I18N_KEYS } from '../../core/i18n/gantt-locale.keys';
import { GanttChartPresenter } from './gantt-chart.presenter';
import { GanttChartView } from '../../components/plans/gantt-chart.view';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

describe('GanttChartPresenter', () => {
  let presenter: GanttChartPresenter;
  let view: GanttChartView;
  let translate: { instant: ReturnType<typeof vi.fn> };
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
      applyBarResetPlanData: vi.fn(),
      requestPlanRefresh: vi.fn(),
      updateChartOnly: vi.fn(),
      resetBarPosition: vi.fn(),
      clearOptimizationLock: vi.fn(),
      engagePlanMutationStaleLock: vi.fn(),
      clearPlanMutationStaleLock: vi.fn(),
      setFieldFormLoading: vi.fn()
    };
    translate = {
      instant: vi.fn((key: string) => `t:${key}`)
    };

    presenter = new GanttChartPresenter(translate as never);
    presenter.setView(view);
  });

  it('shows server-may-have-succeeded message and engages stale lock on refetch_failed', () => {
    presenter.onMutationOutcome(
      { status: 'failure', failure: { refetchFailed: true } },
      { planId: 7, presentation: { onRefetchFailure: 'update_chart' } }
    );

    expect(translate.instant).toHaveBeenCalledWith(GANTT_I18N_KEYS.js.logs.dataRefetchFailed);
    expect(lastControl.pendingErrorFlash).toEqual({
      type: 'error',
      text: `t:${GANTT_I18N_KEYS.js.logs.dataRefetchFailed}`
    });
    expect(view.updateChartOnly).toHaveBeenCalled();
    expect(view.engagePlanMutationStaleLock).toHaveBeenCalledWith(7);
    expect(view.clearOptimizationLock).not.toHaveBeenCalled();
    expect(view.requestPlanRefresh).not.toHaveBeenCalled();
  });

  it('engages stale lock on refetch_error without auto refresh', () => {
    presenter.onMutationOutcome(
      { status: 'failure', failure: { refetchError: true } },
      { planId: 7 }
    );

    expect(translate.instant).toHaveBeenCalledWith(GANTT_I18N_KEYS.js.logs.dataRefetchApiError);
    expect(view.engagePlanMutationStaleLock).toHaveBeenCalledWith(7);
    expect(view.requestPlanRefresh).not.toHaveBeenCalled();
    expect(view.clearOptimizationLock).not.toHaveBeenCalled();
  });

  it('shows API message and reverts bar on message failure', () => {
    presenter.onMutationOutcome(
      { status: 'failure', failure: { message: 'bad request' } },
      { planId: 7, presentation: { revertBarOnMessageFailure: true } }
    );

    expect(lastControl.pendingErrorFlash).toEqual({
      type: 'error',
      text: 'bad request'
    });
    expect(view.resetBarPosition).toHaveBeenCalled();
  });

  it('applies refreshed plan data on success', () => {
    const data = planData();
    presenter.onMutationOutcome({ status: 'success', data }, { planId: 7 });

    expect(view.applyRefreshedPlanData).toHaveBeenCalledWith(data);
  });

  it('onPlanDataLoaded refreshes view data for refresh purpose', () => {
    const data = planData();
    presenter.onPlanDataLoaded({ data, purpose: 'refresh' });

    expect(view.applyRefreshedPlanData).toHaveBeenCalledWith(data);
  });

  it('onPlanDataLoaded resets bar layout for reset_bar purpose', () => {
    const data = planData();
    presenter.onPlanDataLoaded({ data, purpose: 'reset_bar' });

    expect(view.applyBarResetPlanData).toHaveBeenCalledWith(data);
  });

  it('onLoadError surfaces HTTP errors', () => {
    presenter.onLoadError({ message: 'common.api_error.generic', purpose: 'refresh' });

    expect(translate.instant).toHaveBeenCalledWith('common.api_error.generic');
    expect(lastControl.pendingErrorFlash).toEqual({
      type: 'error',
      text: 't:common.api_error.generic'
    });
  });

  it('onMutationOutcome clears field form loading before applying outcome', () => {
    presenter.onMutationOutcome(
      { status: 'success', data: planData() },
      { planId: 7, presentation: undefined }
    );

    expect(view.setFieldFormLoading).toHaveBeenCalledWith(false);
    expect(view.applyRefreshedPlanData).toHaveBeenCalled();
  });
});
