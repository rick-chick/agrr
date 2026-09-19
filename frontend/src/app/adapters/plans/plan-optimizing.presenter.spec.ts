import { TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { PlanOptimizingPresenter } from './plan-optimizing.presenter';
import { PlanOptimizingView, PlanOptimizingViewState } from '../../components/plans/plan-optimizing.view';
import { UxAnalyticsService } from '../../services/ux-analytics.service';

function createView(initial: PlanOptimizingViewState = { status: 'pending', progress: 0, phaseMessage: '' }) {
  let control = initial;
  const onOptimizationCompleted = vi.fn();
  const view: PlanOptimizingView = {
    get control(): PlanOptimizingViewState {
      return control;
    },
    set control(value: PlanOptimizingViewState) {
      control = value;
    },
    onOptimizationCompleted
  };
  return { view, get control() { return control; }, onOptimizationCompleted };
}

describe('PlanOptimizingPresenter', () => {
  let presenter: PlanOptimizingPresenter;
  let uxAnalytics: { trackOptimizationLifecycle: ReturnType<typeof vi.fn> };

  beforeEach(() => {
    uxAnalytics = { trackOptimizationLifecycle: vi.fn() };
    TestBed.configureTestingModule({
      imports: [TranslateModule.forRoot()],
      providers: [
        PlanOptimizingPresenter,
        { provide: UxAnalyticsService, useValue: uxAnalytics }
      ]
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'models.cultivation_plan.phases.task_schedule_generating': 'Generating task plans...'
      },
      true
    );
    translate.setDefaultLang('en');
    translate.use('en');
    presenter = TestBed.inject(PlanOptimizingPresenter);
  });

  it('updates view.control on present(dto)', () => {
    const harness = createView({ status: 'optimizing', progress: 42, phaseMessage: '' });

    presenter.setView(harness.view);
    presenter.present({ status: 'optimizing', progress: 73 });

    expect(harness.control).toEqual({ status: 'optimizing', progress: 73, phaseMessage: '' });
  });

  it('resolves task_schedule_generating message_key for display', () => {
    const harness = createView({ status: 'optimizing', progress: 90, phaseMessage: '' });
    presenter.setView(harness.view);

    presenter.present({
      status: 'optimizing',
      progress: 95,
      message_key: 'models.cultivation_plan.phases.task_schedule_generating'
    });

    expect(harness.control.phaseMessage).toBe('Generating task plans...');
  });

  it('calls onOptimizationCompleted when status becomes completed', () => {
    const { view, onOptimizationCompleted } = createView({ status: 'optimizing', progress: 90, phaseMessage: '' });
    presenter.setView(view);

    presenter.present({ status: 'completed', progress: 100 });

    expect(onOptimizationCompleted).toHaveBeenCalledTimes(1);
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'completed',
      flow: 'plans',
      job_scenario: 'J3'
    });
  });

  it('calls onOptimizationCompleted when progress reaches 100', () => {
    const { view, onOptimizationCompleted } = createView({ status: 'optimizing', progress: 95, phaseMessage: '' });
    presenter.setView(view);

    presenter.present({ status: 'optimizing', progress: 100 });

    expect(onOptimizationCompleted).toHaveBeenCalledTimes(1);
  });

  it('sets failureHint when status is failed', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'models.cultivation_plan.phase_failed.default': 'Process failed',
        'plans.optimizing_live.error.hints.default': 'Try reloading.'
      },
      true
    );
    const harness = createView({ status: 'optimizing', progress: 40, phaseMessage: '' });
    presenter.setView(harness.view);

    presenter.present({
      status: 'failed',
      progress: 40,
      message_key: 'models.cultivation_plan.phase_failed.default'
    });

    expect(harness.control.status).toBe('failed');
    expect(harness.control.phaseMessage).toBe('Process failed');
    expect(harness.control.failureHint).toBe('Try reloading.');
    expect(harness.control.failureCategory).toBe('default');
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'failed',
      flow: 'plans',
      job_scenario: 'J3',
      failure_category: 'default'
    });
  });

  it('sets failed state with connection lost message on presentConnectionLost', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'plans.optimizing_live.error.connection_lost': 'Connection was lost.',
        'plans.optimizing_live.error.hints.default': 'Try reloading.'
      },
      true
    );
    const harness = createView({ status: 'optimizing', progress: 12, phaseMessage: '' });
    presenter.setView(harness.view);

    presenter.presentConnectionLost();

    expect(harness.control.status).toBe('failed');
    expect(harness.control.progress).toBe(12);
    expect(harness.control.phaseMessage).toBe('Connection was lost.');
    expect(harness.control.failureHint).toBe('Try reloading.');
    expect(harness.control.failureCategory).toBe('connection_lost');
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'failed',
      flow: 'plans',
      job_scenario: 'J3',
      failure_category: 'connection_lost'
    });
  });

  it('does not call onOptimizationCompleted while still in progress', () => {
    const { view, onOptimizationCompleted } = createView({ status: 'optimizing', progress: 0, phaseMessage: '' });
    presenter.setView(view);

    presenter.present({ status: 'optimizing', progress: 73 });

    expect(onOptimizationCompleted).not.toHaveBeenCalled();
  });

  it('ignores stale failed messages after optimization completed', () => {
    const harness = createView({
      status: 'completed',
      progress: 100,
      phaseMessage: 'Done'
    });
    presenter.setView(harness.view);

    presenter.present({
      status: 'failed',
      progress: 40,
      message_key: 'models.cultivation_plan.phase_failed.default'
    });

    expect(harness.control.status).toBe('completed');
    expect(harness.control.progress).toBe(100);
    expect(harness.control.phaseMessage).toBe('Done');
  });

  it('ignores connection lost after optimization completed', () => {
    const harness = createView({
      status: 'completed',
      progress: 100,
      phaseMessage: 'Done'
    });
    presenter.setView(harness.view);

    presenter.presentConnectionLost();

    expect(harness.control.status).toBe('completed');
    expect(harness.control.progress).toBe(100);
    expect(harness.control.phaseMessage).toBe('Done');
  });

  it('infers task_schedule_generation category from technical phase_message', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'models.cultivation_plan.phase_failed.task_schedule_generation':
          'Task plan generation failed.',
        'plans.optimizing_live.error.hints.task_schedule_generation':
          'Something went wrong while processing results. Try again.'
      },
      true
    );
    const harness = createView({ status: 'optimizing', progress: 40, phaseMessage: '' });
    presenter.setView(harness.view);

    presenter.present({
      status: 'failed',
      progress: 40,
      message_key: 'models.cultivation_plan.phase_failed.default',
      phase_message: 'task_schedule worker crashed'
    });

    expect(harness.control.phaseMessage).toBe('Task plan generation failed.');
    expect(harness.control.failureHint).toBe(
      'Something went wrong while processing results. Try again.'
    );
    expect(harness.control.failureCategory).toBe('task_schedule_generation');
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'failed',
      flow: 'plans',
      job_scenario: 'J3',
      failure_category: 'task_schedule_generation'
    });
  });

  it('infers optimizing category from technical phase_message', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'models.cultivation_plan.phase_failed.optimizing': 'Optimization failed.',
        'plans.optimizing_live.error.hints.optimizing':
          'Review your crops and cultivation periods, then try again.'
      },
      true
    );
    const harness = createView({ status: 'optimizing', progress: 40, phaseMessage: '' });
    presenter.setView(harness.view);

    presenter.present({
      status: 'failed',
      progress: 40,
      message_key: 'models.cultivation_plan.phase_failed.default',
      phase_message: 'optimizer subprocess failed'
    });

    expect(harness.control.phaseMessage).toBe('Optimization failed.');
    expect(harness.control.failureHint).toBe(
      'Review your crops and cultivation periods, then try again.'
    );
    expect(harness.control.failureCategory).toBe('optimizing');
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'failed',
      flow: 'plans',
      job_scenario: 'J3',
      failure_category: 'optimizing'
    });
  });

  it('does not surface technical phase_message as primary failure text', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'models.cultivation_plan.phase_failed.fetching_weather': 'Failed to fetch weather data.',
        'plans.optimizing_live.error.hints.fetching_weather': 'Check farm location and try again.'
      },
      true
    );
    const harness = createView({ status: 'optimizing', progress: 40, phaseMessage: '' });
    presenter.setView(harness.view);

    presenter.present({
      status: 'failed',
      progress: 40,
      message_key: 'models.cultivation_plan.phase_failed.default',
      phase_message: 'fetch_weather_data failed: InvalidWeatherApiResponse'
    });

    expect(harness.control.phaseMessage).toBe('Failed to fetch weather data.');
    expect(harness.control.phaseMessage).not.toContain('InvalidWeatherApiResponse');
    expect(harness.control.failureHint).toBe('Check farm location and try again.');
    expect(harness.control.failureCategory).toBe('fetching_weather');
    expect(uxAnalytics.trackOptimizationLifecycle).toHaveBeenCalledWith({
      phase: 'failed',
      flow: 'plans',
      job_scenario: 'J3',
      failure_category: 'fetching_weather'
    });
  });

  it('uses i18n default category instead of raw phase_message text', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'models.cultivation_plan.phase_failed.default': 'Process failed',
        'plans.optimizing_live.error.hints.default': 'Try reloading.'
      },
      true
    );
    const harness = createView({ status: 'optimizing', progress: 40, phaseMessage: '' });
    presenter.setView(harness.view);

    presenter.present({
      status: 'failed',
      progress: 40,
      message_key: 'models.cultivation_plan.phase_failed.default',
      phase_message: 'Unexpected backend failure'
    });

    expect(harness.control.phaseMessage).toBe('Process failed');
    expect(harness.control.phaseMessage).not.toBe('Unexpected backend failure');
    expect(harness.control.failureHint).toBe('Try reloading.');
  });

  it('ignores connection lost when progress already reached 100', () => {
    const harness = createView({
      status: 'optimizing',
      progress: 100,
      phaseMessage: 'Almost done'
    });
    presenter.setView(harness.view);

    presenter.presentConnectionLost();

    expect(harness.control.status).toBe('optimizing');
    expect(harness.control.progress).toBe(100);
    expect(harness.control.phaseMessage).toBe('Almost done');
  });

  it('ignores stale failed messages when progress already reached 100', () => {
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'models.cultivation_plan.phase_failed.default': 'Process failed',
        'plans.optimizing_live.error.hints.default': 'Try reloading.'
      },
      true
    );
    const harness = createView({
      status: 'optimizing',
      progress: 100,
      phaseMessage: 'Almost done'
    });
    presenter.setView(harness.view);

    presenter.present({
      status: 'failed',
      progress: 40,
      message_key: 'models.cultivation_plan.phase_failed.default'
    });

    expect(harness.control.status).toBe('optimizing');
    expect(harness.control.progress).toBe(100);
    expect(harness.control.phaseMessage).toBe('Almost done');
    expect(harness.onOptimizationCompleted).not.toHaveBeenCalled();
  });
});
