import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule } from '@ngx-translate/core';
import { vi } from 'vitest';
import { FarmTemperatureChartComponent } from './farm-temperature-chart.component';
import { LoadFarmTemperatureChartUseCase } from '../../../usecase/farms/load-farm-temperature-chart.usecase';
import { FarmTemperatureChartData } from '../../../domain/farms/farm-temperature-chart';
import { FarmTemperatureChartPresenter } from '../../../adapters/farms/farm-temperature-chart.presenter';

const sampleChartData = (period: FarmTemperatureChartData['period']): FarmTemperatureChartData => ({
  farm_id: 1,
  period,
  start_date: '2026-01-01',
  end_date: '2026-03-31',
  observed_only: true,
  data_quality: { expected_days: 90, present_days: 90, missing_days: 0 },
  points: [
    {
      date: '2026-01-01',
      temperature_min: 1,
      temperature_mean: 5,
      temperature_max: 10
    },
    {
      date: '2026-01-02',
      temperature_min: 2,
      temperature_mean: 6,
      temperature_max: 11
    }
  ]
});

describe('FarmTemperatureChartComponent', () => {
  let fixture: ComponentFixture<FarmTemperatureChartComponent>;
  let loadSpy: { execute: ReturnType<typeof vi.fn> };
  let presenter: FarmTemperatureChartPresenter;

  beforeEach(async () => {
    loadSpy = { execute: vi.fn() };

    vi.mock('chart.js/auto', () => ({
      default: vi.fn().mockImplementation(() => ({
        data: { labels: [], datasets: [] },
        destroy: vi.fn(),
        update: vi.fn()
      }))
    }));

    await TestBed.configureTestingModule({
      imports: [FarmTemperatureChartComponent, TranslateModule.forRoot()]
    })
      .overrideProvider(LoadFarmTemperatureChartUseCase, { useValue: loadSpy })
      .compileComponents();

    fixture = TestBed.createComponent(FarmTemperatureChartComponent);
    presenter = fixture.debugElement.injector.get(FarmTemperatureChartPresenter);
    fixture.componentRef.setInput('farmId', 1);
  });

  it('does not render canvas while weather data is fetching', () => {
    fixture.componentRef.setInput('weatherStatus', 'fetching');
    fixture.componentRef.setInput('weatherProgress', 42);
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('canvas')).toBeNull();
    expect(loadSpy.execute).not.toHaveBeenCalled();
  });

  it('loads chart when weather data is completed', () => {
    fixture.componentRef.setInput('weatherStatus', 'completed');
    fixture.detectChanges();

    expect(loadSpy.execute).toHaveBeenCalledWith({ farmId: 1, period: '90d' });
  });

  it('loads chart with parent-selected period input instead of default 90d', () => {
    fixture.componentRef.setInput('selectedPeriod', '30d');
    fixture.componentRef.setInput('weatherStatus', 'completed');
    fixture.detectChanges();

    expect(loadSpy.execute).toHaveBeenCalledWith({ farmId: 1, period: '30d' });
  });

  it('reloads chart when period changes', () => {
    fixture.componentRef.setInput('weatherStatus', 'completed');
    fixture.detectChanges();
    loadSpy.execute.mockClear();

    fixture.componentInstance.selectPeriod('30d');
    fixture.detectChanges();

    expect(loadSpy.execute).toHaveBeenCalledWith({ farmId: 1, period: '30d' });
  });

  it('keeps canvas mounted while reloading another period', () => {
    fixture.componentRef.setInput('weatherStatus', 'completed');
    fixture.detectChanges();

    presenter.present(sampleChartData('90d'));
    fixture.detectChanges();

    fixture.componentInstance.selectPeriod('30d');
    fixture.detectChanges();

    expect(fixture.componentInstance.control.loading).toBe(true);
    expect(fixture.nativeElement.querySelector('canvas')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('.farm-temperature-chart__loading-overlay')).not.toBeNull();
  });

  it('ignores stale chart responses after period changes', () => {
    fixture.componentRef.setInput('weatherStatus', 'completed');
    fixture.detectChanges();

    presenter.present(sampleChartData('90d'));
    fixture.detectChanges();

    fixture.componentInstance.selectPeriod('30d');
    fixture.detectChanges();

    presenter.present(sampleChartData('90d'));
    fixture.detectChanges();

    expect(fixture.componentInstance.control.loading).toBe(true);
    expect(fixture.componentInstance.control.chartData?.period).toBe('90d');

    presenter.present(sampleChartData('30d'));
    fixture.detectChanges();

    expect(fixture.componentInstance.control.loading).toBe(false);
    expect(fixture.componentInstance.control.chartData?.period).toBe('30d');
  });

  it('keeps chart section visible after weather status was completed once', () => {
    fixture.componentRef.setInput('weatherStatus', 'completed');
    fixture.detectChanges();

    presenter.present(sampleChartData('90d'));
    fixture.detectChanges();

    fixture.componentRef.setInput('weatherStatus', 'fetching');
    fixture.detectChanges();

    expect(fixture.componentInstance.weatherChartEnabled).toBe(true);
    expect(fixture.nativeElement.querySelector('canvas')).not.toBeNull();
  });

  it('shows error and retries load when presenter reports failure', () => {
    fixture.componentRef.setInput('weatherStatus', 'completed');
    fixture.detectChanges();

    presenter.onError({ message: 'farms.weather_section.load_failed' });
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('.farm-temperature-chart__error')).toBeTruthy();
    const retry = fixture.nativeElement.querySelector(
      '.farm-temperature-chart__retry'
    ) as HTMLButtonElement;
    expect(retry).toBeTruthy();
    loadSpy.execute.mockClear();

    retry.click();
    fixture.detectChanges();

    expect(loadSpy.execute).toHaveBeenCalledWith({ farmId: 1, period: '90d' });
  });

  it('marks the selected period button as active', () => {
    fixture.componentRef.setInput('weatherStatus', 'completed');
    fixture.detectChanges();

    presenter.present(sampleChartData('90d'));
    fixture.detectChanges();

    const buttons = () =>
      Array.from(
        fixture.nativeElement.querySelectorAll('.farm-temperature-chart__period-btn')
      ) as HTMLButtonElement[];

    expect(buttons()[1].classList.contains('farm-temperature-chart__period-btn--active')).toBe(
      true
    );

    fixture.componentInstance.selectPeriod('30d');
    fixture.detectChanges();

    expect(buttons()[0].classList.contains('farm-temperature-chart__period-btn--active')).toBe(
      true
    );
  });
});
