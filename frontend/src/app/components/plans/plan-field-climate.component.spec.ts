import { SimpleChange, SimpleChanges, ChangeDetectorRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TranslateModule } from '@ngx-translate/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { TranslateService } from '@ngx-translate/core';

import type { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import { LoadFieldClimateInputDto } from '../../usecase/plans/field-climate/load-field-climate.dtos';
import { LoadFieldClimateUseCase } from '../../usecase/plans/field-climate/load-field-climate.usecase';
import { PlanFieldClimatePresenter } from '../../adapters/plans/plan-field-climate.presenter';
import { PlanFieldClimateComponent } from './plan-field-climate.component';

vi.mock('chart.js/auto', () => ({
  default: class ChartMock {
    data = { labels: [] as string[], datasets: [] as unknown[] };
    update = vi.fn();
    destroy = vi.fn();
    resize = vi.fn();
  }
}));

describe('PlanFieldClimateComponent', () => {
  let mockPresenter: Pick<PlanFieldClimatePresenter, 'setView' | 'present' | 'onError'>;
  let mockUseCase: LoadFieldClimateUseCase;
  let mockCdr: ChangeDetectorRef;
  let mockTranslate: TranslateService;
  let component: PlanFieldClimateComponent;

  beforeEach(() => {
    mockPresenter = {
      setView: vi.fn(),
      present: vi.fn(),
      onError: vi.fn()
    };

    mockUseCase = { execute: vi.fn() } as unknown as LoadFieldClimateUseCase;
    mockCdr = { markForCheck: vi.fn() } as unknown as ChangeDetectorRef;
    mockTranslate = {
      instant: vi.fn((key: string) => key),
      onLangChange: { subscribe: vi.fn() }
    } as unknown as TranslateService;

    component = new PlanFieldClimateComponent(
      mockPresenter as PlanFieldClimatePresenter,
      mockUseCase,
      mockCdr,
      mockTranslate
    );
    component.ngOnInit();
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  it('registers itself as the presenter view on init', () => {
    expect(mockPresenter.setView).toHaveBeenCalledWith(component);
  });

  it('calls useCase.execute when a cultivation selection changes', () => {
    component.planType = 'public';
    component.fieldCultivationId = 42;

    const changes: SimpleChanges = {
      fieldCultivationId: new SimpleChange(null, 42, true),
      planType: new SimpleChange('private', 'public', true)
    };

    component.ngOnChanges(changes);

    const expectedPayload: LoadFieldClimateInputDto = {
      fieldCultivationId: 42,
      planType: 'public',
      displayStartDate: null,
      displayEndDate: null
    };

    expect(mockUseCase.execute).toHaveBeenCalledWith(expectedPayload);
  });

  it('marks for check when control is updated via the view contract', () => {
    const sampleData: FieldCultivationClimateData = {
      success: true,
      field_cultivation: {
        id: 1,
        field_name: 'Field A',
        crop_name: 'Tomato',
        start_date: '2026-02-01',
        completion_date: '2026-04-01'
      },
      farm: {
        id: 1,
        name: 'Test Farm',
        latitude: 35.0,
        longitude: 139.0
      },
      crop_requirements: {
        base_temperature: 12
      },
      weather_data: [],
      gdd_data: [],
      stages: []
    };

    component.control = {
      loading: false,
      error: null,
      climateData: sampleData
    };

    expect(component.control.climateData).toBe(sampleData);
    expect(mockCdr.markForCheck).toHaveBeenCalled();
  });

  it('defaults activeChartTab to temperature', () => {
    expect(component.activeChartTab).toBe('temperature');
  });

  it('keeps activeChartTab when switching to another field cultivation', () => {
    const firstField: FieldCultivationClimateData = {
      success: true,
      field_cultivation: {
        id: 1,
        field_name: 'Field A',
        crop_name: 'Tomato',
        start_date: '2026-02-01',
        completion_date: '2026-04-01'
      },
      farm: { id: 1, name: 'Test Farm', latitude: 35.0, longitude: 139.0 },
      crop_requirements: { base_temperature: 12 },
      weather_data: [],
      gdd_data: [],
      stages: []
    };
    const secondField: FieldCultivationClimateData = {
      ...firstField,
      field_cultivation: { ...firstField.field_cultivation, id: 2, crop_name: 'Pepper' }
    };

    component.control = { loading: false, error: null, climateData: firstField };
    component.selectChartTab('gdd');
    component.control = { loading: false, error: null, climateData: secondField };

    expect(component.activeChartTab).toBe('gdd');
  });

  it('selectChartTab switches activeChartTab and resizes the visible chart', async () => {
    const resize = vi.fn();
    const chartStub = {
      resize,
      data: { labels: [] as string[], datasets: [] as unknown[] },
      update: vi.fn()
    };
    (component as unknown as { gddChart: typeof chartStub }).gddChart = chartStub;

    component.selectChartTab('gdd');

    expect(component.activeChartTab).toBe('gdd');
    await Promise.resolve();
    expect(resize).toHaveBeenCalled();
  });
});

describe('PlanFieldClimateComponent (template)', () => {
  let fixture: ComponentFixture<PlanFieldClimateComponent>;
  let component: PlanFieldClimateComponent;

  const sampleData: FieldCultivationClimateData = {
    success: true,
    field_cultivation: {
      id: 1,
      field_name: 'Field A',
      crop_name: 'Tomato',
      start_date: '2026-02-01',
      completion_date: '2026-04-01'
    },
    farm: { id: 1, name: 'Test Farm', latitude: 35.0, longitude: 139.0 },
    crop_requirements: { base_temperature: 12 },
    weather_data: [{ date: '2026-02-01', temperature_min: 5, temperature_mean: 10, temperature_max: 15 }],
    gdd_data: [{ date: '2026-02-01', gdd: 1, cumulative_gdd: 1, current_stage: 'Germination' }],
    stages: [
      { name: 'Germination', order: 1, gdd_required: 200, cumulative_gdd_required: 200 }
    ]
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [PlanFieldClimateComponent, TranslateModule.forRoot()]
    }).compileComponents();

    fixture = TestBed.createComponent(PlanFieldClimateComponent);
    component = fixture.componentInstance;
    component.fieldCultivationId = 1;
    fixture.detectChanges();
  });

  it('renders chart-first layout markers and mobile chart tabs when climate data is shown', () => {
    component.control = { loading: false, error: null, climateData: sampleData };
    fixture.detectChanges();

    const root = fixture.nativeElement as HTMLElement;
    expect(root.querySelector('.plan-field-climate__content--chart-first')).toBeTruthy();
    expect(root.querySelector('[role="tablist"]')).toBeTruthy();
    expect(root.querySelector('.plan-field-climate__charts--tab-temperature')).toBeTruthy();
  });

  it('applies gdd tab modifier class when gdd tab is selected', () => {
    component.control = { loading: false, error: null, climateData: sampleData };
    fixture.detectChanges();

    component.selectChartTab('gdd');
    fixture.detectChanges();

    const charts = (fixture.nativeElement as HTMLElement).querySelector('.plan-field-climate__charts');
    expect(charts?.classList.contains('plan-field-climate__charts--tab-gdd')).toBe(true);
  });
});
