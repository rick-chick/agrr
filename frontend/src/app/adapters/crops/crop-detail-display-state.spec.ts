import { describe, expect, it } from 'vitest';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';
import { withCropDetailDisplayState } from './crop-detail-display-state';
import type { CropDetailViewState } from '../../components/masters/crops/crop-detail.view';

const baseControl: CropDetailViewState = {
  loading: false,
  error: null,
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
  pendingUndoToast: null,
  pendingErrorFlash: null,
  pendingSuccessFlash: null,
  fromPlanId: null,
  agriculturalTasksLoading: false,
  agriculturalTasks: [
    { id: 5, name: 'Weeding', required_tools: [], is_reference: false },
    { id: 6, name: 'Fertilizing', required_tools: [], is_reference: false }
  ],
  unassociatedAgriculturalTasks: [],
  blueprintsLoading: false,
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
      source: 'agrr',
      priority: 1,
      amount: null,
      amount_unit: null,
      description: null,
      weather_dependency: null,
      time_per_sqm: null
    }
  ],
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
};

describe('withCropDetailDisplayState', () => {
  it('enriches blueprint display names from agricultural tasks when API omits name', () => {
    const control: CropDetailViewState = {
      ...baseControl,
      blueprints: [
        {
          id: 21,
          crop_id: 3,
          agricultural_task_id: 6,
          source_agricultural_task_id: null,
          stage_order: 0,
          stage_name: null,
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
    };

    const result = withCropDetailDisplayState(control);

    expect(result.blueprints[0]?.name).toBe('Fertilizing');
    expect(result.blueprints[0]?.agricultural_task?.name).toBe('Fertilizing');
  });

  it('filters unassociated agricultural tasks', () => {
    const result = withCropDetailDisplayState(baseControl);

    expect(result.unassociatedAgriculturalTasks.map((task) => task.id)).toEqual([6]);
  });

  it('enables regenerate when readiness is satisfied and not regenerating', () => {
    const result = withCropDetailDisplayState(baseControl);

    expect(result.blueprintReadiness.ready).toBe(true);
    expect(result.canRegenerateBlueprints).toBe(true);
    expect(result.showBlueprintReadinessChecklist).toBe(false);
  });

  it('shows readiness checklist when stage requirements are incomplete', () => {
    const result = withCropDetailDisplayState({
      ...baseControl,
      crop: { ...baseControl.crop!, crop_stages: [] }
    });

    expect(result.canRegenerateBlueprints).toBe(false);
    expect(result.showBlueprintReadinessChecklist).toBe(true);
  });

  it('derives create form state from selections', () => {
    const result = withCropDetailDisplayState({
      ...baseControl,
      selectedBlueprintAgriculturalTaskId: 6,
      selectedBlueprintStageOrder: 1
    });

    expect(result.canCreateBlueprint).toBe(true);
    expect(result.blueprintStageNameForCreate).toBe('Vegetative');
  });

  it('uses empty-state description and hides empty message when regenerate failed', () => {
    const empty = withCropDetailDisplayState({
      ...baseControl,
      blueprints: []
    });
    expect(empty.blueprintSectionDescriptionKey).toBe(
      'crops.show.task_schedule_blueprints_description_empty_html'
    );
    expect(empty.showBlueprintEmptyState).toBe(true);

    const failed = withCropDetailDisplayState({
      ...baseControl,
      blueprintRegenerateError: 'crops.show.blueprint_errors.generic'
    });
    expect(failed.showBlueprintEmptyState).toBe(false);
    expect(failed.showBlueprintRegenerateRetry).toBe(true);
  });

  it('groups blueprints into stage lanes for the board layout', () => {
    const result = withCropDetailDisplayState(baseControl);

    expect(result.blueprintStageLanes.map((lane) => lane.stageOrder)).toEqual([null, 1]);
    expect(result.blueprintStageLanes[1].blueprints.map((b) => b.id)).toEqual([20]);
  });
});
