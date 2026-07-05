import { TestBed } from '@angular/core/testing';
import { describe, expect, it, beforeEach } from 'vitest';
import { CropDetailPresenter } from './crop-detail.presenter';
import { CropDetailView, CropDetailViewState } from '../../components/masters/crops/crop-detail.view';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';
import {
  defaultBlueprintReadiness,
  withCropDetailDisplayState
} from './crop-detail-presenter.helpers';

const baseControl: CropDetailViewState = withCropDetailDisplayState({
  loading: false,
  error: null,
  crop: { id: 3, name: 'Tomato', is_reference: false, groups: [] },
  pendingUndoToast: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  fromPlanId: null,
  agriculturalTasksLoading: false,
  agriculturalTasks: [],
  unassociatedAgriculturalTasks: [],
  blueprintsLoading: false,
  blueprints: [],
  blueprintsRegenerating: false,
  blueprintSavingId: null,
  blueprintGddDrafts: {},
  blueprintStageLanes: [],
  blueprintRegenerateError: null,
  selectedBlueprintStageOrder: null,
  selectedBlueprintAgriculturalTaskId: null,
  blueprintCreateGddTrigger: null,
  blueprintCreating: false,
  blueprintReadiness: defaultBlueprintReadiness(),
  canRegenerateBlueprints: false,
  canCreateBlueprint: false,
  blueprintStageNameForCreate: null,
  showBlueprintReadinessChecklist: false,
  blueprintSectionDescriptionKey: 'crops.show.task_schedule_blueprints_description_empty_html',
  showBlueprintEmptyState: true,
  showBlueprintRegenerateRetry: false
});

describe('CropDetailPresenter', () => {
  let presenter: CropDetailPresenter;
  let lastControl: CropDetailViewState;
  let view: CropDetailView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CropDetailPresenter, { provide: ListRefreshBus, useValue: { refresh: () => {} } }]
    });
    presenter = TestBed.inject(CropDetailPresenter);
    lastControl = { ...baseControl };
    view = {
      get control(): CropDetailViewState {
        return lastControl;
      },
      set control(value: CropDetailViewState) {
        lastControl = value;
      },
      reload: () => {}
    };
    presenter.setView(view);
  });

  it('shows inline blueprint regenerate error without flash when regenerating fails', () => {
    lastControl = { ...baseControl, blueprintsRegenerating: true };

    presenter.onError({
      message: 'crops.show.blueprint_errors.missing_blueprints'
    });

    expect(lastControl.blueprintRegenerateError).toBe(
      'crops.show.blueprint_errors.missing_blueprints'
    );
    expect(lastControl.pendingErrorFlash).toBeNull();
    expect(lastControl.blueprintsRegenerating).toBe(false);
  });

  it('uses flash for non-regenerate errors', () => {
    presenter.onError({ message: 'common.api_error.generic' });

    expect(lastControl.blueprintRegenerateError).toBeNull();
    expect(lastControl.pendingErrorFlash).toEqual({
      type: 'error',
      text: 'common.api_error.generic'
    });
  });

  it('clears blueprint regenerate error on successful blueprint list present', () => {
    lastControl = {
      ...baseControl,
      blueprintsRegenerating: true,
      blueprintRegenerateError: 'crops.show.blueprint_errors.generic'
    };

    presenter.present({
      blueprints: [
        {
          id: 1,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 100,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'agrr',
          priority: 1,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null
        }
      ]
    });

    expect(lastControl.blueprintRegenerateError).toBeNull();
    expect(lastControl.blueprintsRegenerating).toBe(false);
    expect(lastControl.blueprintGddDrafts).toEqual({ 1: 100 });
  });

  it('filters unassociated agricultural tasks by existing blueprints', () => {
    lastControl = {
      ...baseControl,
      blueprints: [
        {
          id: 20,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 100,
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
    };

    presenter.present({
      tasks: [
        { id: 5, name: 'Weeding', required_tools: [], is_reference: false },
        { id: 6, name: 'Fertilizing', required_tools: [], is_reference: false }
      ]
    });

    expect(lastControl.unassociatedAgriculturalTasks.map((t) => t.id)).toEqual([6]);
  });

  it('appends manually created blueprint and clears create form state', () => {
    lastControl = {
      ...baseControl,
      blueprintCreating: true,
      selectedBlueprintStageOrder: 1,
      selectedBlueprintAgriculturalTaskId: 5,
      blueprintCreateGddTrigger: 120,
      blueprints: []
    };

    presenter.present({
      blueprint: {
        id: 22,
        crop_id: 3,
        agricultural_task_id: 5,
        source_agricultural_task_id: null,
        stage_order: 1,
        stage_name: 'Vegetative',
        gdd_trigger: 120,
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
    });

    expect(lastControl.blueprintCreating).toBe(false);
    expect(lastControl.selectedBlueprintStageOrder).toBeNull();
    expect(lastControl.blueprints).toHaveLength(1);
    expect(lastControl.blueprints[0].source).toBe('manual');
    expect(lastControl.blueprintGddDrafts[22]).toBe(120);
  });

  it('sets blueprintSavingId when blueprint update starts', () => {
    presenter.onUpdateStarted(42);

    expect(lastControl.blueprintSavingId).toBe(42);
  });

  it('updates blueprint stage and recomputes stage lanes on blueprint update present', () => {
    const existingBlueprint = {
      id: 10,
      crop_id: 3,
      agricultural_task_id: 5,
      source_agricultural_task_id: null,
      stage_order: 1,
      stage_name: 'Vegetative',
      gdd_trigger: 100,
      gdd_tolerance: null,
      task_type: 'field_work' as const,
      source: 'agrr' as const,
      priority: 1,
      amount: null,
      amount_unit: null,
      description: null,
      weather_dependency: null,
      time_per_sqm: null
    };
    lastControl = withCropDetailDisplayState({
      ...baseControl,
      crop: {
        id: 3,
        name: 'Tomato',
        is_reference: false,
        groups: [],
        crop_stages: [
          { id: 1, crop_id: 3, name: 'Vegetative', order: 1 },
          { id: 2, crop_id: 3, name: 'Flowering', order: 2 }
        ]
      },
      blueprintSavingId: 10,
      blueprints: [existingBlueprint],
      blueprintGddDrafts: { 10: 100 }
    });

    presenter.present({
      blueprint: {
        ...existingBlueprint,
        stage_order: 2,
        stage_name: 'Flowering',
        gdd_trigger: 150
      }
    });

    expect(lastControl.blueprintSavingId).toBeNull();
    expect(lastControl.blueprintGddDrafts[10]).toBe(150);
    expect(lastControl.blueprints[0].stage_order).toBe(2);
    expect(lastControl.blueprintStageLanes[2].blueprints.map((b) => b.id)).toEqual([10]);
  });

  it('derives blueprint display state when crop detail is presented', () => {
    lastControl = {
      ...baseControl,
      crop: {
        id: 3,
        name: 'Tomato',
        is_reference: false,
        groups: [],
        crop_stages: [
          {
            id: 1,
            crop_id: 3,
            name: 'Vegetative',
            order: 1,
            temperature_requirement: {
              id: 1,
              crop_stage_id: 1,
              base_temperature: 10,
              optimal_min: 15,
              optimal_max: 25
            },
            thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 500 }
          }
        ]
      },
      blueprints: [
        {
          id: 1,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 100,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'agrr',
          priority: 1,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null
        }
      ]
    };

    presenter.present({ crop: lastControl.crop! });

    expect(lastControl.canRegenerateBlueprints).toBe(true);
    expect(lastControl.showBlueprintReadinessChecklist).toBe(false);
    expect(lastControl.blueprintSectionDescriptionKey).toBe(
      'crops.show.task_schedule_blueprints_description_html'
    );
  });
});
