import { vi } from 'vitest';
import { PlanOptimizingPresenter } from './plan-optimizing.presenter';
import { PlanOptimizingView, PlanOptimizingViewState } from '../../components/plans/plan-optimizing.view';

function createView(initial: PlanOptimizingViewState = { status: 'pending', progress: 0 }) {
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
  it('updates view.control on present(dto)', () => {
    const harness = createView({ status: 'optimizing', progress: 42 });
    const presenter = new PlanOptimizingPresenter();
    presenter.setView(harness.view);

    presenter.present({ status: 'optimizing', progress: 73 });

    expect(harness.control).toEqual({ status: 'optimizing', progress: 73 });
  });

  it('calls onOptimizationCompleted when status becomes completed', () => {
    const { view, onOptimizationCompleted } = createView({ status: 'optimizing', progress: 90 });
    const presenter = new PlanOptimizingPresenter();
    presenter.setView(view);

    presenter.present({ status: 'completed', progress: 100 });

    expect(onOptimizationCompleted).toHaveBeenCalledTimes(1);
  });

  it('calls onOptimizationCompleted when progress reaches 100', () => {
    const { view, onOptimizationCompleted } = createView({ status: 'optimizing', progress: 95 });
    const presenter = new PlanOptimizingPresenter();
    presenter.setView(view);

    presenter.present({ status: 'optimizing', progress: 100 });

    expect(onOptimizationCompleted).toHaveBeenCalledTimes(1);
  });

  it('does not call onOptimizationCompleted while still in progress', () => {
    const { view, onOptimizationCompleted } = createView({ status: 'optimizing', progress: 0 });
    const presenter = new PlanOptimizingPresenter();
    presenter.setView(view);

    presenter.present({ status: 'optimizing', progress: 73 });

    expect(onOptimizationCompleted).not.toHaveBeenCalled();
  });
});
