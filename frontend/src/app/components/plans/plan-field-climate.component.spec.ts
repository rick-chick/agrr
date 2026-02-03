import { SimpleChange, SimpleChanges, ChangeDetectorRef } from '@angular/core';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import type { FieldCultivationClimateData } from '../../domain/plans/field-cultivation-climate-data';
import { LoadFieldClimateInputDto } from '../../usecase/plans/field-climate/load-field-climate.dtos';
import { LoadFieldClimateUseCase } from '../../usecase/plans/field-climate/load-field-climate.usecase';
import { PlanFieldClimatePresenter } from '../../adapters/plans/plan-field-climate.presenter';
import { PlanFieldClimateView } from './plan-field-climate.view';
import { PlanFieldClimateComponent } from './plan-field-climate.component';

vi.mock('chart.js/auto', () => ({
  default: vi.fn().mockImplementation(() => ({
    data: { labels: [], datasets: [] },
    update: vi.fn(),
    destroy: vi.fn()
  }))
}));

describe('PlanFieldClimateComponent', () => {
  let component: PlanFieldClimateComponent;
  let mockPresenter: PlanFieldClimatePresenter;
  let mockUseCase: LoadFieldClimateUseCase;
  let mockCdr: ChangeDetectorRef;
  let capturedView: PlanFieldClimateView | null;

  beforeEach(() => {
    capturedView = null;

    mockPresenter = {
      setView: vi.fn((view: PlanFieldClimateView) => {
        capturedView = view;
      }),
      present: vi.fn((data: FieldCultivationClimateData) => {
        if (!capturedView) return;
        capturedView.control = {
          loading: false,
          error: null,
          climateData: data
        };
      }),
      onError: vi.fn()
    } as unknown as PlanFieldClimatePresenter;

    mockUseCase = { execute: vi.fn() } as unknown as LoadFieldClimateUseCase;
    mockCdr = { markForCheck: vi.fn() } as unknown as ChangeDetectorRef;

    component = new PlanFieldClimateComponent(mockPresenter, mockUseCase, mockCdr);
    component.ngOnInit();
  });

  afterEach(() => {
    vi.clearAllMocks();
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
      planType: 'public'
    };

    expect(mockUseCase.execute).toHaveBeenCalledWith(expectedPayload);
  });

  it('updates control when presenter emits climate data', () => {
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
      stages: [],
      progress_result: {},
      debug_info: {}
    };

    mockPresenter.present(sampleData);

    expect(component.control.climateData).toBe(sampleData);
    expect(mockCdr.markForCheck).toHaveBeenCalled();
  });
});
