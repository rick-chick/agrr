import { FieldClimatePresenter } from './field-climate.presenter';
import {
  FieldClimateView,
  FieldClimateViewState
} from '../../components/plans/field-climate.view';
import { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import { ErrorDto } from '../../domain/shared/error.dto';

type ViewFixture = {
  view: FieldClimateView;
  getState(): FieldClimateViewState;
};

const createViewFixture = (): ViewFixture => {
  let currentState: FieldClimateViewState = {
    loading: true,
    error: null,
    data: null
  };

  return {
    view: {
      get control(): FieldClimateViewState {
        return currentState;
      },
      set control(value: FieldClimateViewState) {
        currentState = value;
      }
    },
    getState: () => currentState
  };
};

describe('FieldClimatePresenter', () => {
  const climateData: FieldCultivationClimateData = {
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
      base_temperature: 10,
      optimal_temperature_range: {
        min: 15,
        max: 25,
        low_stress: 13,
        high_stress: 30
      }
    },
    weather_data: [],
    gdd_data: [],
    stages: [],
    progress_result: {},
    debug_info: {}
  };

  it('hydrates view.control when present succeeds', () => {
    const { view, getState } = createViewFixture();
    const presenter = new FieldClimatePresenter();
    presenter.setView(view);

    presenter.present(climateData);

    expect(getState()).toEqual({
      loading: false,
      error: null,
      data: climateData
    });
  });

  it('sets view.control when present fails', () => {
    const { view, getState } = createViewFixture();
    const presenter = new FieldClimatePresenter();
    presenter.setView(view);

    presenter.onError({ message: 'boom' } as ErrorDto);

    expect(getState()).toEqual({
      loading: false,
      error: 'boom',
      data: null
    });
  });
});
