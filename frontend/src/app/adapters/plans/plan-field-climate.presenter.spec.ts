import { describe, expect, it } from 'vitest';

import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import {
  PlanFieldClimateView,
  PlanFieldClimateViewState
} from '../../components/plans/plan-field-climate.view';
import { PlanFieldClimatePresenter } from './plan-field-climate.presenter';

type ViewFixture = {
  view: PlanFieldClimateView;
  getState(): PlanFieldClimateViewState;
};

const createViewFixture = (): ViewFixture => {
  let currentState: PlanFieldClimateViewState = {
    loading: true,
    error: null,
    climateData: null,
    workDayMarkers: [],
    latestImplementation: null
  };

  return {
    view: {
      get control(): PlanFieldClimateViewState {
        return currentState;
      },
      set control(value: PlanFieldClimateViewState) {
        currentState = value;
      }
    },
    getState: () => currentState
  };
};

const sampleClimateData: FieldCultivationClimateData = {
  success: true,
  field_cultivation: {
    id: 1,
    field_name: 'North Field',
    crop_name: 'Tomato',
    start_date: '2026-01-01',
    completion_date: '2026-06-01'
  },
  farm: {
    id: 2,
    name: 'Test Farm',
    latitude: 35,
    longitude: 139
  },
  crop_requirements: {
    base_temperature: 12
  },
  weather_data: [],
  gdd_data: [],
  stages: []
};

describe('PlanFieldClimatePresenter', () => {
  it('present maps climate data into view control', () => {
    const fixture = createViewFixture();
    const presenter = new PlanFieldClimatePresenter();
    presenter.setView(fixture.view);

    presenter.present({
      climateData: sampleClimateData,
      workDayMarkers: [{ actualDate: '2026-06-12', name: 'Weeding', taskScheduleItemId: 5 }],
      latestImplementation: { name: 'Weeding', deltaDaysLabel: '+2', gddDeltaLabel: '+10' }
    });

    const state = fixture.getState();
    expect(state.loading).toBe(false);
    expect(state.error).toBeNull();
    expect(state.climateData).toBe(sampleClimateData);
    expect(state.workDayMarkers).toHaveLength(1);
    expect(state.latestImplementation?.name).toBe('Weeding');
  });

  it('onError maps message into view control', () => {
    const fixture = createViewFixture();
    const presenter = new PlanFieldClimatePresenter();
    presenter.setView(fixture.view);

    presenter.onError({ message: 'climate failed' });

    const state = fixture.getState();
    expect(state.loading).toBe(false);
    expect(state.climateData).toBeNull();
    expect(state.error).toBe('climate failed');
    expect(state.workDayMarkers).toEqual([]);
  });

  it('throws when view is not set', () => {
    const presenter = new PlanFieldClimatePresenter();

    expect(() =>
      presenter.present({
        climateData: sampleClimateData,
        workDayMarkers: [],
        latestImplementation: null
      })
    ).toThrow(/view not set/);
    expect(() => presenter.onError({ message: 'x' })).toThrow(/view not set/);
  });
});
