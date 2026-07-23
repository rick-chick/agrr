import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule } from '@ngx-translate/core';
import { vi } from 'vitest';
import { FarmTemperatureChartComponent } from './farm-temperature-chart.component';
import { LoadFarmTemperatureChartUseCase } from '../../../usecase/farms/load-farm-temperature-chart.usecase';

describe('FarmTemperatureChartComponent', () => {
  let fixture: ComponentFixture<FarmTemperatureChartComponent>;
  let loadSpy: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    loadSpy = { execute: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [FarmTemperatureChartComponent, TranslateModule.forRoot()]
    })
      .overrideProvider(LoadFarmTemperatureChartUseCase, { useValue: loadSpy })
      .compileComponents();

    fixture = TestBed.createComponent(FarmTemperatureChartComponent);
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

  it('reloads chart when period changes', () => {
    fixture.componentRef.setInput('weatherStatus', 'completed');
    fixture.detectChanges();
    loadSpy.execute.mockClear();

    fixture.componentInstance.selectPeriod('30d');
    fixture.detectChanges();

    expect(loadSpy.execute).toHaveBeenCalledWith({ farmId: 1, period: '30d' });
  });
});
