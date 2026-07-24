import { TestBed } from '@angular/core/testing';
import { FarmTemperatureChartPresenter } from './farm-temperature-chart.presenter';
import {
  FarmTemperatureChartView,
  FarmTemperatureChartViewState
} from '../../components/masters/farms/farm-temperature-chart.view';
import { FarmTemperatureChartData } from '../../domain/farms/farm-temperature-chart';

describe('FarmTemperatureChartPresenter', () => {
  let presenter: FarmTemperatureChartPresenter;
  let lastControl: FarmTemperatureChartViewState | null;
  let view: FarmTemperatureChartView;

  const sampleData: FarmTemperatureChartData = {
    farm_id: 1,
    period: '90d',
    start_date: '2026-04-24',
    end_date: '2026-07-23',
    observed_only: true,
    data_quality: {
      expected_days: 90,
      present_days: 90,
      missing_days: 0
    },
    points: [
      {
        date: '2026-07-22',
        temperature_min: 18.2,
        temperature_mean: 24.5,
        temperature_max: 30.1
      }
    ]
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [FarmTemperatureChartPresenter]
    });
    presenter = TestBed.inject(FarmTemperatureChartPresenter);
    lastControl = {
      loading: true,
      error: null,
      chartData: null
    };
    view = {
      get control(): FarmTemperatureChartViewState {
        return lastControl!;
      },
      set control(value: FarmTemperatureChartViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  it('present clears loading and sets chartData', () => {
    presenter.present(sampleData);

    expect(lastControl).toEqual({
      loading: false,
      error: null,
      chartData: sampleData
    });
  });

  it('onError clears loading and sets error message', () => {
    presenter.onError({ message: 'farms.weather_section.chart_fetching' });

    expect(lastControl).toEqual({
      loading: false,
      error: 'farms.weather_section.chart_fetching',
      chartData: null
    });
  });

  it('throws when view is not set', () => {
    const unbound = new FarmTemperatureChartPresenter();
    expect(() => unbound.present(sampleData)).toThrow('Presenter: view not set');
  });
});
