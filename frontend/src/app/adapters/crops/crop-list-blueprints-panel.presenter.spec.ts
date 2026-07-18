import { TestBed } from '@angular/core/testing';
import { describe, it, expect, beforeEach } from 'vitest';
import { CropListBlueprintsPanelPresenter } from './crop-list-blueprints-panel.presenter';
import {
  CropListBlueprintsPanelView,
  CropListBlueprintsPanelViewState
} from '../../components/masters/crops/crop-list-blueprints-panel.view';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';

describe('CropListBlueprintsPanelPresenter', () => {
  let presenter: CropListBlueprintsPanelPresenter;
  let lastControl: CropListBlueprintsPanelViewState | null;

  const initialControl: CropListBlueprintsPanelViewState = {
    loading: true,
    error: null,
    crop: null,
    blueprintsLoading: true,
    blueprintCount: 0,
    blueprintReadiness: defaultBlueprintReadiness(),
    blueprintSummary: null
  };

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CropListBlueprintsPanelPresenter]
    });
    presenter = TestBed.inject(CropListBlueprintsPanelPresenter);
    lastControl = { ...initialControl };
    const view: CropListBlueprintsPanelView = {
      get control(): CropListBlueprintsPanelViewState {
        return lastControl ?? initialControl;
      },
      set control(value: CropListBlueprintsPanelViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  it('presents crop load by clearing loading and setting crop', () => {
    const crop = {
      id: 10,
      name: 'Tomato',
      variety: null,
      is_reference: false,
      groups: [],
      crop_stages: []
    };

    presenter.present({ crop });

    expect(lastControl?.loading).toBe(false);
    expect(lastControl?.error).toBeNull();
    expect(lastControl?.crop).toEqual(crop);
  });

  it('presents blueprints load with summary when loading completes', () => {
    lastControl = {
      ...initialControl,
      loading: false,
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
      },
      blueprintsLoading: true
    };

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

    expect(lastControl?.blueprintsLoading).toBe(false);
    expect(lastControl?.blueprintCount).toBe(1);
    expect(lastControl?.blueprintReadiness.ready).toBe(true);
    expect(lastControl?.blueprintSummary).not.toBeNull();
  });

  it('onError clears loading flags and resets blueprint summary', () => {
    lastControl = {
      ...initialControl,
      loading: false,
      crop: {
        id: 10,
        name: 'Tomato',
        variety: null,
        is_reference: false,
        groups: [],
        crop_stages: []
      },
      blueprintCount: 2,
      blueprintSummary: { lanes: [], unsetTimingCount: 0, issueCount: 0, attentionCount: 1 }
    };

    presenter.onError({ message: 'crops.errors.load_failed' });

    expect(lastControl?.loading).toBe(false);
    expect(lastControl?.blueprintsLoading).toBe(false);
    expect(lastControl?.error).toBe('crops.errors.load_failed');
    expect(lastControl?.blueprintCount).toBe(0);
    expect(lastControl?.blueprintSummary).toBeNull();
    expect(lastControl?.blueprintReadiness).toEqual(defaultBlueprintReadiness());
  });
});
