import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach } from 'vitest';
import { PublicPlanResultsPresenter } from './public-plan-results.presenter';
import { PublicPlanResultsView, PublicPlanResultsViewState } from '../../components/public-plans/public-plan-results.view';

describe('PublicPlanResultsPresenter', () => {
  let presenter: PublicPlanResultsPresenter;
  let view: PublicPlanResultsView;
  let lastControl: PublicPlanResultsViewState | null;

  beforeEach(() => {
    TestBed.resetTestingModule();

    TestBed.configureTestingModule({
      providers: [PublicPlanResultsPresenter]
    });

    presenter = TestBed.inject(PublicPlanResultsPresenter);
    lastControl = null;
    view = {
      get control(): PublicPlanResultsViewState {
        return lastControl ?? {
          loading: true,
          error: null,
          data: null,
          pendingErrorFlash: null,
          pendingSuccessFlash: null,
          pendingNavigation: null
        };
      },
      set control(value: PublicPlanResultsViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  describe('SavePublicPlanOutputPort', () => {
    it('queues navigation to plan detail when cultivation_plan_id is returned', () => {
      presenter.present({
        message: 'Plan saved successfully',
        plan_reused: false,
        cultivation_plan_id: 99
      });

      expect(lastControl!.pendingNavigation).toEqual({ commands: ['/plans', 99] });
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'Plan saved successfully'
      });
    });

    it('queues navigation to plans list when cultivation_plan_id is absent', () => {
      presenter.present({ message: 'Plan saved successfully', plan_reused: false });

      expect(lastControl!.pendingNavigation).toEqual({ commands: ['/plans'] });
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'Plan saved successfully'
      });
    });

    it('queues navigation to existing plan detail when plan_reused', () => {
      presenter.present({
        message: 'Plan already exists',
        plan_reused: true,
        cultivation_plan_id: 42
      });

      expect(lastControl!.pendingNavigation).toEqual({ commands: ['/plans', 42] });
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'Plan already exists'
      });
    });

    it('keeps gantt data and only flashes on save error when data is already loaded', () => {
      lastControl = {
        loading: false,
        error: null,
        data: { id: 1 } as never,
        pendingErrorFlash: null,
        pendingSuccessFlash: null,
        pendingNavigation: null
      };

      presenter.onError({ message: 'Failed to save plan' });

      expect(lastControl!.pendingErrorFlash).toEqual({ type: 'error', text: 'Failed to save plan' });
      expect(lastControl!.data).toEqual({ id: 1 });
      expect(lastControl!.error).toBeNull();
    });

    it('replaces view with error state on load error when data is absent', () => {
      presenter.onError({ message: 'Failed to load plan' });

      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.error).toBe('Failed to load plan');
      expect(lastControl!.data).toBeNull();
    });
  });
});
