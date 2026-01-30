import { PlanDetailPresenter } from './plan-detail.presenter';
import { PlanDetailView, PlanDetailViewState } from '../../components/plans/plan-detail.view';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import { PlanDetailDataDto } from '../../usecase/plans/load-plan-detail.dtos';

describe('PlanDetailPresenter', () => {
  const plan: PlanSummary = { id: 1, name: 'Plan A', status: 'pending' };
  const planData: CultivationPlanData = {
    success: true,
    data: {
      id: 1,
      plan_year: 2025,
      plan_name: 'Plan A',
      status: 'pending',
      total_area: 10,
      planning_start_date: '2025-01-01',
      planning_end_date: '2025-12-31',
      fields: [],
      crops: [],
      cultivations: []
    },
    total_profit: 0,
    total_revenue: 0,
    total_cost: 0
  };

  it('updates view.control on present(dto)', () => {
    let lastControl: PlanDetailViewState | null = null;
    const view: PlanDetailView = {
      get control(): PlanDetailViewState {
        return lastControl ?? { loading: true, error: null, plan: null, planData: null };
      },
      set control(value: PlanDetailViewState) {
        lastControl = value;
      }
    };

    const presenter = new PlanDetailPresenter();
    presenter.setView(view);
    presenter.present({ plan, planData } as PlanDetailDataDto);

    expect(lastControl).not.toBeNull();
    expect(lastControl!.loading).toBe(false);
    expect(lastControl!.error).toBeNull();
    expect(lastControl!.plan?.id).toBe(1);
    expect(lastControl!.planData?.data.plan_name).toBe('Plan A');
  });

  it('updates view.control on onError(dto)', () => {
    let lastControl: PlanDetailViewState | null = null;
    const view: PlanDetailView = {
      get control(): PlanDetailViewState {
        return lastControl ?? { loading: true, error: null, plan: null, planData: null };
      },
      set control(value: PlanDetailViewState) {
        lastControl = value;
      }
    };

    const presenter = new PlanDetailPresenter();
    presenter.setView(view);
    presenter.onError({ message: 'boom' });

    expect(lastControl).not.toBeNull();
    expect(lastControl!.loading).toBe(false);
    expect(lastControl!.error).toBe('boom');
    expect(lastControl!.plan).toBeNull();
    expect(lastControl!.planData).toBeNull();
  });
});
