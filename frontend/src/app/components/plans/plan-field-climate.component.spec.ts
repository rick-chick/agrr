import { SimpleChange, SimpleChanges, ChangeDetectorRef } from '@angular/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { TranslateService } from '@ngx-translate/core';

import type { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import { LoadFieldClimateInputDto } from '../../usecase/plans/field-climate/load-field-climate.dtos';
import { LoadFieldClimateUseCase } from '../../usecase/plans/field-climate/load-field-climate.usecase';
import { PlanFieldClimatePresenter } from '../../adapters/plans/plan-field-climate.presenter';
import { PlanFieldClimateComponent } from './plan-field-climate.component';

vi.mock('chart.js/auto', () => ({
  default: vi.fn().mockImplementation(() => ({
    data: { labels: [], datasets: [] },
    update: vi.fn(),
    destroy: vi.fn()
  }))
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
    mockTranslate = { instant: vi.fn((key: string) => key) } as unknown as TranslateService;

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
});
