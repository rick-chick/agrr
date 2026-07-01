import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { WorkHubPresenter } from './work-hub.presenter';
import { WorkHubViewState } from '../../components/work-hub/work-hub.view';

describe('WorkHubPresenter', () => {
  let presenter: WorkHubPresenter;
  let lastControl: WorkHubViewState;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [WorkHubPresenter]
    });

    presenter = TestBed.inject(WorkHubPresenter);
    lastControl = {
      loading: true,
      submitting: false,
      error: null,
      farms: [],
      pendingSuccessFlash: null,
      pendingNavigation: null
    };
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

    expect(lastControl).toEqual({
      loading: false,
      submitting: false,
      error: null,
      farms: [
        {
          farmId: 1,
          farmName: 'Farm A',
          fieldCount: 2,
          totalArea: 100,
          hasValidFields: true,
          planId: 9
        }
      ],
      pendingSuccessFlash: null,
      pendingNavigation: null
    });
  });

  it('sets submitting when ensure begins', () => {
    lastControl = {
      loading: false,
      submitting: false,
      error: 'old',
      farms: [],
      pendingSuccessFlash: null,
      pendingNavigation: null
    };

    presenter.beginEnsure();

    expect(lastControl.submitting).toBe(true);
    expect(lastControl.error).toBeNull();
    expect(lastControl.pendingSuccessFlash).toBeNull();
  });

  it('queues navigation to work screen on ensure success without pending success flash when plan existed', () => {
    lastControl = {
      loading: false,
      submitting: true,
      error: null,
      farms: [],
      pendingSuccessFlash: null,
      pendingNavigation: null
    };

    presenter.onSuccess({ planId: 42, created: false });

    expect(lastControl.pendingSuccessFlash).toBeNull();
    expect(lastControl.pendingNavigation).toEqual({
      commands: ['/plans', 42, 'work']
    });
  });

  it('queues pending success flash and navigation when a new plan was created', () => {
    lastControl = {
      loading: false,
      submitting: true,
      error: null,
      farms: [],
      pendingSuccessFlash: null,
      pendingNavigation: null
    };

    presenter.onSuccess({ planId: 99, created: true });

    expect(lastControl.pendingSuccessFlash).toEqual({
      type: 'success',
      text: 'plans.messages.plan_created'
    });
    expect(lastControl.pendingNavigation).toEqual({
      commands: ['/plans', 99, 'work']
    });
  });
});
