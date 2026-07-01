import { TestBed } from '@angular/core/testing';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { vi } from 'vitest';
import { PlanOptimizingPresenter } from './plan-optimizing.presenter';
import { PlanOptimizingView, PlanOptimizingViewState } from '../../components/plans/plan-optimizing.view';

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

  beforeEach(() => {
    TestBed.configureTestingModule({
      imports: [TranslateModule.forRoot()],
      providers: [PlanOptimizingPresenter]
    });
    const translate = TestBed.inject(TranslateService);
    translate.setTranslation(
      'en',
      {
        'models.cultivation_plan.phases.task_schedule_generating': 'Generating task schedules...'
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

    expect(harness.control.phaseMessage).toBe('Generating task schedules...');
  });

  it('calls onOptimizationCompleted when status becomes completed', () => {
    const { view, onOptimizationCompleted } = createView({ status: 'optimizing', progress: 90, phaseMessage: '' });
    presenter.setView(view);

    presenter.present({ status: 'completed', progress: 100 });

    expect(onOptimizationCompleted).toHaveBeenCalledTimes(1);
  });

  it('calls onOptimizationCompleted when progress reaches 100', () => {
    const { view, onOptimizationCompleted } = createView({ status: 'optimizing', progress: 95, phaseMessage: '' });
    presenter.setView(view);

    presenter.present({ status: 'optimizing', progress: 100 });

    expect(onOptimizationCompleted).toHaveBeenCalledTimes(1);
  });

  it('does not call onOptimizationCompleted while still in progress', () => {
    const { view, onOptimizationCompleted } = createView({ status: 'optimizing', progress: 0, phaseMessage: '' });
    presenter.setView(view);

    presenter.present({ status: 'optimizing', progress: 73 });

    expect(onOptimizationCompleted).not.toHaveBeenCalled();
  });
});
