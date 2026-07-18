import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { TranslateModule, TranslateService } from '@ngx-translate/core';
import { describe, it, expect, beforeEach, vi } from 'vitest';

import { CropListBlueprintsPanelComponent } from './crop-list-blueprints-panel.component';
import {
  CropListBlueprintsPanelPresenter,
  CROP_LIST_BLUEPRINTS_PANEL_PROVIDERS
} from '../../../usecase/crops/crop-list-blueprints-panel.providers';
import { LoadCropForEditUseCase } from '../../../usecase/crops/load-crop-for-edit.usecase';
import { LoadCropTaskScheduleBlueprintsUseCase } from '../../../usecase/crops/load-crop-task-schedule-blueprints.usecase';

const translations = {
  common: {
    loading: 'Loading…'
  },
  crops: {
    show: {
      blueprint_readiness: {
        detail_title: 'Setup status',
        stages_ready: 'Stages ready',
        stages_missing: 'Stages missing',
        blueprints_ready: 'Task plans ready',
        blueprints_missing: 'Task plans missing'
      },
      blueprint_summary: {
        count: '{{count}} task plans',
        attention_suffix: '({{count}} need attention)',
        setup_required: 'Complete setup before generating schedules.'
      }
    },
    index: {
      inline: {
        blueprints_full_edit: 'Edit task plans'
      }
    }
  }
};

describe('CropListBlueprintsPanelComponent', () => {
  let fixture: ComponentFixture<CropListBlueprintsPanelComponent>;
  let presenter: CropListBlueprintsPanelPresenter;
  let loadCropUseCase: { execute: ReturnType<typeof vi.fn> };
  let loadBlueprintsUseCase: { execute: ReturnType<typeof vi.fn> };

  beforeEach(async () => {
    loadCropUseCase = { execute: vi.fn() };
    loadBlueprintsUseCase = { execute: vi.fn() };

    await TestBed.configureTestingModule({
      imports: [CropListBlueprintsPanelComponent, TranslateModule.forRoot()],
      providers: [
        provideRouter([]),
        ...CROP_LIST_BLUEPRINTS_PANEL_PROVIDERS,
        { provide: LoadCropForEditUseCase, useValue: loadCropUseCase },
        { provide: LoadCropTaskScheduleBlueprintsUseCase, useValue: loadBlueprintsUseCase }
      ]
    })
      .overrideComponent(CropListBlueprintsPanelComponent, { set: { providers: [] } })
      .compileComponents();

    const translate = TestBed.inject(TranslateService);
    translate.setTranslation('en', translations, true);
    translate.use('en');

    fixture = TestBed.createComponent(CropListBlueprintsPanelComponent);
    fixture.componentRef.setInput('cropId', 10);
    presenter = fixture.debugElement.injector.get(CropListBlueprintsPanelPresenter);
    fixture.detectChanges();
  });

  it('loads crop and blueprints on init', () => {
    expect(loadCropUseCase.execute).toHaveBeenCalledWith({ cropId: 10 });
    expect(loadBlueprintsUseCase.execute).toHaveBeenCalledWith({ cropId: 10 });
  });

  it('shows loading state initially', () => {
    expect(fixture.nativeElement.textContent).toContain('Loading…');
    expect(fixture.nativeElement.querySelector('[data-testid="crop-list-blueprints-panel"]')).not.toBeNull();
  });

  it('shows readiness checklist and blueprint count when loaded', () => {
    presenter.present({
      crop: {
        id: 10,
        name: 'Tomato',
        variety: null,
        is_reference: false,
        groups: [],
        crop_stages: [
          {
            id: 1,
            crop_id: 10,
            name: 'Seedling',
            order: 1,
            temperature_requirement: {
              id: 1,
              crop_stage_id: 1,
              base_temperature: 10,
              optimal_min: 15,
              optimal_max: 25
            },
            thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 200 }
          }
        ]
      }
    });
    presenter.present({
      blueprints: [
        {
          id: 1,
          crop_id: 10,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Seedling',
          gdd_trigger: 50,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'manual',
          priority: 1,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null
        }
      ]
    });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Setup status');
    expect(fixture.nativeElement.textContent).toContain('1 task plans');
    expect(fixture.nativeElement.textContent).toContain('Edit task plans');
    expect(fixture.nativeElement.querySelector('a[href]')).not.toBeNull();
  });

  it('shows setup hint when readiness is incomplete', () => {
    presenter.present({
      crop: {
        id: 10,
        name: 'Tomato',
        variety: null,
        is_reference: false,
        groups: [],
        crop_stages: []
      }
    });
    presenter.present({ blueprints: [] });
    fixture.detectChanges();

    expect(fixture.nativeElement.textContent).toContain('Complete setup before generating schedules.');
  });
});
