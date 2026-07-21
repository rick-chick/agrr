import { SimpleChange, SimpleChanges, ChangeDetectorRef } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { FarmTemperatureChartComponent } from './farm-temperature-chart.component';
import { FarmTemperatureChartPresenter } from '../../../adapters/farms/farm-temperature-chart.presenter';
import { LoadFarmTemperatureChartUseCase } from '../../../usecase/farms/load-farm-temperature-chart.usecase';
import { LoadFarmTemperatureChartInputDto } from '../../../usecase/farms/load-farm-temperature-chart.dtos';
import type { FarmTemperatureChart } from '../../../domain/farms/farm-temperature-chart';

vi.mock('chart.js/auto', () => ({
  default: class ChartMock {
    data = { labels: [] as string[], datasets: [] as unknown[] };
    update = vi.fn();
    destroy = vi.fn();
    resize = vi.fn();
  }
}));

describe('FarmTemperatureChartComponent', () => {
  let mockPresenter: Pick<FarmTemperatureChartPresenter, 'setView' | 'present' | 'onError' | 'onNotReady'>;
  let mockUseCase: LoadFarmTemperatureChartUseCase;
  let mockCdr: ChangeDetectorRef;
  let mockTranslate: TranslateService;
  let component: FarmTemperatureChartComponent;

  beforeEach(() => {
    mockPresenter = {
      setView: vi.fn(),
      present: vi.fn(),
      onError: vi.fn(),
      onNotReady: vi.fn()
    };

    mockUseCase = { execute: vi.fn() } as unknown as LoadFarmTemperatureChartUseCase;
    mockCdr = { markForCheck: vi.fn() } as unknown as ChangeDetectorRef;
    mockTranslate = {
      instant: vi.fn((key: string) => key),
      currentLang: 'ja',
      onLangChange: { subscribe: vi.fn(() => ({ unsubscribe: vi.fn() })) }
    } as unknown as TranslateService;

    component = new FarmTemperatureChartComponent(
      mockPresenter as FarmTemperatureChartPresenter,
      mockUseCase,
      mockCdr,
      mockTranslate
    );
    component.farmId = 12;
    component.ngOnInit();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('registers itself as the presenter view on init', () => {
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
  });

  it('calls useCase.execute when weather_data_status is completed', () => {
    component.weatherDataStatus = 'completed';

    const changes: SimpleChanges = {
      weatherDataStatus: new SimpleChange(undefined, 'completed', true)
    };

    component.ngOnChanges(changes);

    const expectedPayload: LoadFarmTemperatureChartInputDto = {
      farmId: 12,
      period: '90d'
    };

    expect(mockUseCase.execute).toHaveBeenCalledWith(expectedPayload);
  });

  it('does not call useCase.execute while weather data is fetching', () => {
    component.weatherDataStatus = 'fetching';

    const changes: SimpleChanges = {
      weatherDataStatus: new SimpleChange(undefined, 'fetching', true)
    };

    component.ngOnChanges(changes);

    expect(mockUseCase.execute).not.toHaveBeenCalled();
  });

  it('reloads chart when period changes', () => {
    component.weatherDataStatus = 'completed';
    component.ngOnChanges({
      weatherDataStatus: new SimpleChange(undefined, 'completed', true)
    });
    vi.mocked(mockUseCase.execute).mockClear();

    component.selectPeriod('180d');

    expect(mockUseCase.execute).toHaveBeenCalledWith({
      farmId: 12,
      period: '180d'
    });
  });

  it('marks for check when control is updated via the view contract', () => {
    const sampleData: FarmTemperatureChart = {
      farm_id: 12,
      period: '90d',
      start_date: '2026-04-23',
      end_date: '2026-07-21',
      observed_only: true,
      data_quality: { expected_days: 90, present_days: 88, missing_days: 2 },
      points: []
    };

    component.control = {
      loading: false,
      error: null,
      chartData: sampleData,
      notReady: false
    };

    expect(component.control.chartData).toBe(sampleData);
    expect(mockCdr.markForCheck).toHaveBeenCalled();
  });
});
