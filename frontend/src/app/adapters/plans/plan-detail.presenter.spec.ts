import { PlanDetailPresenter } from './plan-detail.presenter';
import { PlanDetailView, PlanDetailViewState } from '../../components/plans/plan-detail.view';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';
import { PlanSummary } from '../../domain/plans/plan-summary';
import type { WeatherRescheduleProposal } from '../../domain/plans/weather-reschedule-proposal';
import { readDismissedWeatherRescheduleProposalIds } from '../../domain/plans/weather-reschedule-proposal-session';

const emptyWeatherState = {
  weatherProposals: [],
  activeWeatherProposalId: null,
  weatherPreviewLoading: false,
  weatherPreviewError: null,
  weatherPreview: null,
  weatherOverlayBars: [],
  weatherApplyLoading: false,
  weatherApplyError: null
};

describe('PlanDetailPresenter', () => {
  const plan: PlanSummary = { id: 1, name: 'Plan A', status: 'pending', farm_id: 1 };
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
        return lastControl ?? {
          loading: true,
          error: null,
          plan: null,
          planData: null,
          varianceActionItemsOnGantt: [],
          ...emptyWeatherState
        };
      },
      set control(value: PlanDetailViewState) {
        lastControl = value;
      }
    };

    const presenter = new PlanDetailPresenter();
    presenter.setView(view);
    presenter.present({ plan, planData, varianceActionItemsOnGantt: [], weatherProposals: [] });

    expect(lastControl).not.toBeNull();
    expect(lastControl!.loading).toBe(false);
    expect(lastControl!.error).toBeNull();
    expect(lastControl!.plan?.id).toBe(1);
    expect(lastControl!.planData?.data.plan_name).toBe('Plan A');
    expect(lastControl!.weatherProposals).toEqual([]);
  });

  it('updates view.control on onError(dto)', () => {
    let lastControl: PlanDetailViewState | null = null;
    const view: PlanDetailView = {
      get control(): PlanDetailViewState {
        return lastControl ?? {
          loading: true,
          error: null,
          plan: null,
          planData: null,
          varianceActionItemsOnGantt: [],
          ...emptyWeatherState
        };
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

  it('onApplied dismisses active weather proposal without clearing plan data', () => {
    const weatherProposal: WeatherRescheduleProposal = {
      id: 'frost_forecast:10:1',
      trigger_type: 'frost_forecast',
      severity: 'high',
      rationale: {},
      moves: []
    };
    let lastControl: PlanDetailViewState = {
      loading: false,
      error: null,
      plan,
      planData,
      varianceActionItemsOnGantt: [],
      weatherProposals: [weatherProposal],
      activeWeatherProposalId: weatherProposal.id,
      weatherPreviewLoading: false,
      weatherPreviewError: null,
      weatherPreview: {
        proposal_id: weatherProposal.id,
        moves: [],
        proposal: weatherProposal,
        before: { field_schedules: [] },
        after: { field_schedules: [] }
      },
      weatherOverlayBars: [],
      weatherApplyLoading: true,
      weatherApplyError: null
    };
    const view: PlanDetailView = {
      get control(): PlanDetailViewState {
        return lastControl;
      },
      set control(value: PlanDetailViewState) {
        lastControl = value;
      }
    };

    const presenter = new PlanDetailPresenter();
    presenter.setView(view);
    presenter.onApplied();

    expect(lastControl.weatherProposals).toEqual([]);
    expect(lastControl.activeWeatherProposalId).toBeNull();
    expect(lastControl.weatherPreview).toBeNull();
    expect(lastControl.planData).toBe(planData);
    expect(readDismissedWeatherRescheduleProposalIds(plan.id)).toContain(weatherProposal.id);
  });
});
