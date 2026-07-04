import { TestBed } from '@angular/core/testing';
import { describe, expect, it, beforeEach } from 'vitest';
import { CropDetailPresenter } from './crop-detail.presenter';
import { CropDetailView, CropDetailViewState } from '../../components/masters/crops/crop-detail.view';
import { ListRefreshBus } from '../../core/list-refresh/list-refresh-bus.service';

const baseControl: CropDetailViewState = {
  loading: false,
  error: null,
  crop: { id: 3, name: 'Tomato', is_reference: false, groups: [] },
  pendingUndoToast: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  taskTemplatesLoading: false,
  taskTemplates: [],
  agriculturalTasksLoading: false,
  agriculturalTasks: [],
  unassociatedAgriculturalTasks: [],
  selectedAgriculturalTaskId: null,
  taskTemplateCreating: false,
  blueprintsLoading: false,
  blueprints: [],
  blueprintsRegenerating: false,
  blueprintGddSavingId: null,
  blueprintGddDrafts: {},
  blueprintRegenerateError: null,
  selectedBlueprintStageOrder: null,
  selectedBlueprintAgriculturalTaskId: null,
  blueprintCreateGddTrigger: null,
  blueprintCreating: false
};

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
      message: 'crops.show.blueprint_errors.missing_task_templates'
    });

    expect(lastControl.blueprintRegenerateError).toBe(
      'crops.show.blueprint_errors.missing_task_templates'
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
  });

  it('filters unassociated agricultural tasks for picker', () => {
    lastControl = {
      ...baseControl,
      taskTemplates: [
        {
          id: 10,
          crop_id: 3,
          agricultural_task_id: 5,
          name: 'Weeding',
          required_tools: [],
          agricultural_task: { id: 5, name: 'Weeding', is_reference: false }
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
});
