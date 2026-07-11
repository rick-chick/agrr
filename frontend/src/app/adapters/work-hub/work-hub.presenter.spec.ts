import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';
import { WorkHubPresenter } from './work-hub.presenter';
import { WorkHubViewState } from '../../components/work-hub/work-hub.view';

function baseControl(overrides: Partial<WorkHubViewState> = {}): WorkHubViewState {
  return {
    loading: true,
    submitting: false,
    error: null,
    farms: [],
    scheduleLoading: true,
    scheduleError: null,
    scheduleRows: [],
    scheduleFilter: { farmId: null, fieldCultivationId: null },
    pendingSuccessFlash: null,
    pendingNavigation: null,
    ...overrides
  };
}

describe('WorkHubPresenter', () => {
  let presenter: WorkHubPresenter;
  let lastControl: WorkHubViewState;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [WorkHubPresenter]
    });

    presenter = TestBed.inject(WorkHubPresenter);
    lastControl = baseControl();
    presenter.setView({
      get control() {
        return lastControl;
      },
      set control(value: WorkHubViewState) {
        lastControl = value;
      }
    });
  });

  it('maps loaded farms to view control', () => {
    presenter.present({
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9
        }
      ]
    });

    expect(lastControl).toEqual(
      baseControl({
        loading: false,
        farms: [
          {
            farmId: 1,
            farmName: 'Farm A',
            fieldCount: 2,
            totalArea: 100,
            hasValidFields: true,
            planId: 9
          }
        ]
      })
    );
  });

  it('sets submitting when ensure begins', () => {
    lastControl = baseControl({ loading: false, error: 'old' });

    presenter.beginEnsure();

    expect(lastControl.submitting).toBe(true);
    expect(lastControl.error).toBeNull();
    expect(lastControl.pendingSuccessFlash).toBeNull();
  });

  it('queues navigation to work screen on ensure success without pending success flash when plan existed', () => {
    lastControl = baseControl({ loading: false, submitting: true });

    presenter.onSuccess({ planId: 42, created: false });

    expect(lastControl.pendingSuccessFlash).toBeNull();
    expect(lastControl.pendingNavigation).toEqual({
      commands: ['/plans', 42, 'work']
    });
  });

  it('queues pending success flash and navigation when a new plan was created', () => {
    lastControl = baseControl({ loading: false, submitting: true });

    presenter.onSuccess({ planId: 99, created: true });

    expect(lastControl.pendingSuccessFlash).toEqual({
      type: 'success',
      text: 'plans.messages.plan_created'
    });
    expect(lastControl.pendingNavigation).toEqual({
      commands: ['/plans', 99, 'work']
    });
  });

  it('maps cross-farm schedule rows to view control', () => {
    lastControl = baseControl({ loading: false, scheduleLoading: true });

    presenter.presentSchedule({
      rows: [
        {
          item: {
            item_id: 1,
            name: 'Weeding',
            scheduled_date: '2026-06-10',
            status: 'planned'
          } as WorkHubViewState['scheduleRows'][number]['item'],
          farmId: 1,
          farmName: 'Farm A',
          planId: 9,
          planName: 'Plan A',
          fieldName: 'Field 1',
          fieldCultivationId: 101,
          cropName: 'Tomato'
        }
      ]
    });

    expect(lastControl.scheduleLoading).toBe(false);
    expect(lastControl.scheduleRows).toHaveLength(1);
    expect(lastControl.scheduleError).toBeNull();
  });

  it('maps schedule load errors to view control', () => {
    lastControl = baseControl({ loading: false, scheduleLoading: true });

    presenter.onScheduleError({ message: 'common.api_error.generic' });

    expect(lastControl.scheduleLoading).toBe(false);
    expect(lastControl.scheduleError).toBe('common.api_error.generic');
    expect(lastControl.scheduleRows).toEqual([]);
  });
});
