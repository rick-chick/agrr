import { describe, it, expect, beforeEach } from 'vitest';
import { HomeDemoSectionPresenter } from './home-demo-section.presenter';
import { HomeDemoSectionView } from '../../components/home/home-demo-section.view';
import { CultivationPlanData } from '../../domain/plans/cultivation-plan-data';

describe('HomeDemoSectionPresenter', () => {
  let presenter: HomeDemoSectionPresenter;
  let view: HomeDemoSectionView & { lastPlanData?: CultivationPlanData };

  const planData = (): CultivationPlanData =>
    ({
      data: {
        id: 1,
        planning_start_date: '2026-01-01',
        planning_end_date: '2026-12-31',
        fields: [{ id: 1, name: 'Field 1' }],
        cultivations: []
      }
    }) as CultivationPlanData;

  beforeEach(() => {
    presenter = new HomeDemoSectionPresenter();
    view = {
      applyDemoPlanData: (data) => {
        view.lastPlanData = data;
      }
    };
    presenter.setView(view);
  });

  it('writes loaded demo plan data to the view', () => {
    const data = planData();
    presenter.onDemoPlanLoaded({ data });
    expect(view.lastPlanData).toEqual(data);
  });
});
