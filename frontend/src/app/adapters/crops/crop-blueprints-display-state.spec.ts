import { describe, expect, it } from 'vitest';
import { withCropBlueprintDisplayState } from './crop-blueprints-display-state';
import type { CropTaskScheduleBlueprintsViewState } from '../../components/masters/crops/crop-task-schedule-blueprints.view';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';
import type { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';

function blueprint(
  overrides: Partial<CropTaskScheduleBlueprint> & Pick<CropTaskScheduleBlueprint, 'id'>
): CropTaskScheduleBlueprint {
  return {
    crop_id: 1,
    agricultural_task_id: 1,
    source_agricultural_task_id: null,
    stage_order: 1,
    stage_name: '定植期',
    gdd_trigger: 50,
    gdd_tolerance: null,
    task_type: 'field_work',
    source: 'manual',
    priority: 1,
    amount: null,
    amount_unit: null,
    description: null,
    weather_dependency: null,
    time_per_sqm: null,
    ...overrides
  };
}

const baseControl: CropTaskScheduleBlueprintsViewState = {
  loading: false,
  error: null,
  crop: {
    id: 1,
    name: 'Tomato',
    variety: null,
    area_per_unit: null,
    revenue_per_area: null,
    groups: [],
    region: 'jp',
    is_reference: false,
    crop_stages: [
      {
        id: 1,
        crop_id: 1,
        name: '定植期',
        order: 1,
        thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 200 }
      },
      {
        id: 2,
        crop_id: 1,
        name: '生育期',
        order: 2,
        thermal_requirement: { id: 2, crop_stage_id: 2, required_gdd: 300 }
      }
    ],
    created_at: null,
    updated_at: null
  },
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
  blueprintGddTouched: {},
  blueprintStageLanes: [],
  cumulativeGddTimelineSegments: [],
  blueprintGddErrors: {},
  blueprintLaneOutOfRangeCounts: {},
  blueprintCreateGddError: null,
  blueprintCreateFormAttempted: false,
  selectedStageGddRange: null,
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
  showBlueprintEmptyState: true,
  showBlueprintRegenerateRetry: false
};

describe('withCropBlueprintDisplayState', () => {
  it('hides blueprint GDD errors until the field was touched', () => {
    const control = {
      ...baseControl,
      blueprints: [blueprint({ id: 10, gdd_trigger: 500 })],
      blueprintGddDrafts: { 10: 500 }
    };
    expect(withCropBlueprintDisplayState({ ...control, blueprintGddTouched: {} }).blueprintGddErrors).toEqual(
      {}
    );
    expect(
      withCropBlueprintDisplayState({ ...control, blueprintGddTouched: { 10: true } }).blueprintGddErrors
    ).toEqual({ 10: 'out_of_range' });
  });

  it('disables canCreateBlueprint when crop has stages but no stage is selected before form attempt', () => {
    const next = withCropBlueprintDisplayState({
      ...baseControl,
      selectedBlueprintAgriculturalTaskId: 6,
      blueprintCreateFormAttempted: false,
      selectedBlueprintStageOrder: null
    });
    expect(next.canCreateBlueprint).toBe(false);
    expect(next.blueprintCreateGddError).toBeNull();
  });

  it('sets blueprintCreateGddError to missing_stage when crop has stages but create form has no stage', () => {
    const next = withCropBlueprintDisplayState({
      ...baseControl,
      selectedBlueprintAgriculturalTaskId: 6,
      blueprintCreateFormAttempted: true,
      selectedBlueprintStageOrder: null
    });
    expect(next.blueprintCreateGddError).toBe('missing_stage');
    expect(next.canCreateBlueprint).toBe(false);
  });

  it('sets blueprintCreateGddError to out_of_range when create GDD exceeds stage band', () => {
    const next = withCropBlueprintDisplayState({
      ...baseControl,
      selectedBlueprintAgriculturalTaskId: 6,
      selectedBlueprintStageOrder: 1,
      blueprintCreateGddTrigger: 250,
      blueprintCreateFormAttempted: true
    });
    expect(next.blueprintCreateGddError).toBe('out_of_range');
    expect(next.canCreateBlueprint).toBe(false);
  });

  it('computes blueprintLaneOutOfRangeCounts for lanes with invalid GDD', () => {
    const next = withCropBlueprintDisplayState({
      ...baseControl,
      blueprints: [blueprint({ id: 10, stage_order: 1, gdd_trigger: 250 })],
      blueprintGddDrafts: { 10: 250 }
    });
    expect(next.blueprintLaneOutOfRangeCounts).toEqual({ 1: 1 });
  });

  it('populates cumulativeGddTimelineSegments from crop stages with GDD', () => {
    const next = withCropBlueprintDisplayState(baseControl);
    expect(next.cumulativeGddTimelineSegments).toEqual([
      {
        stageOrder: 1,
        stageName: '定植期',
        cumulativeGddStart: 0,
        cumulativeGddEnd: 200
      },
      {
        stageOrder: 2,
        stageName: '生育期',
        cumulativeGddStart: 200,
        cumulativeGddEnd: 500
      }
    ]);
  });

  it('populates selectedStageGddRange when a stage is selected for create', () => {
    const next = withCropBlueprintDisplayState({
      ...baseControl,
      selectedBlueprintStageOrder: 2
    });
    expect(next.selectedStageGddRange).toEqual({
      cumulativeGddStart: 200,
      cumulativeGddEnd: 500,
      gddRangeMissing: false
    });
  });

  describe('showBlueprintEmptyState', () => {
    it('is true when blueprints are empty and there is no regenerate error', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        blueprints: [],
        blueprintRegenerateError: null
      });
      expect(next.showBlueprintEmptyState).toBe(true);
    });

    it('is false when blueprints exist', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        blueprints: [blueprint({ id: 10, gdd_trigger: 50 })],
        blueprintRegenerateError: null
      });
      expect(next.showBlueprintEmptyState).toBe(false);
    });

    it('is false when a regenerate error is present even if blueprints are empty', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        blueprints: [],
        blueprintRegenerateError: 'crops.show.blueprint_errors.generic'
      });
      expect(next.showBlueprintEmptyState).toBe(false);
    });
  });

  describe('showBlueprintRegenerateRetry', () => {
    const cropWithRequirements = {
      ...baseControl.crop!,
      crop_stages: [
        {
          id: 1,
          crop_id: 1,
          name: '定植期',
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
    };

    it('is true when readiness is ready and regenerate error allows retry', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        crop: cropWithRequirements,
        blueprints: [blueprint({ id: 10, task_type: 'field_work', gdd_trigger: 50 })],
        blueprintRegenerateError: 'crops.show.blueprint_errors.generic'
      });
      expect(next.showBlueprintRegenerateRetry).toBe(true);
    });

    it('is false when readiness is not ready', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        crop: baseControl.crop,
        blueprints: [],
        blueprintRegenerateError: 'crops.show.blueprint_errors.generic'
      });
      expect(next.showBlueprintRegenerateRetry).toBe(false);
    });

    it('is false when there is no regenerate error', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        crop: cropWithRequirements,
        blueprints: [blueprint({ id: 10, task_type: 'field_work', gdd_trigger: 50 })],
        blueprintRegenerateError: null
      });
      expect(next.showBlueprintRegenerateRetry).toBe(false);
    });

    it('is false when regenerate error blocks retry', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        crop: cropWithRequirements,
        blueprints: [blueprint({ id: 10, task_type: 'field_work', gdd_trigger: 50 })],
        blueprintRegenerateError: 'crops.show.blueprint_errors.missing_blueprints'
      });
      expect(next.showBlueprintRegenerateRetry).toBe(false);
    });
  });

  describe('showBlueprintReadinessChecklist', () => {
    it('is true when not loading, readiness is incomplete, and not regenerating', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        blueprintsLoading: false,
        blueprints: [],
        blueprintsRegenerating: false
      });
      expect(next.showBlueprintReadinessChecklist).toBe(true);
    });

    it('is false while blueprints are loading', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        blueprintsLoading: true,
        blueprints: [],
        blueprintsRegenerating: false
      });
      expect(next.showBlueprintReadinessChecklist).toBe(false);
    });

    it('is false when readiness is satisfied', () => {
      const cropWithRequirements = {
        ...baseControl.crop!,
        crop_stages: [
          {
            id: 1,
            crop_id: 1,
            name: '定植期',
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
      };
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        crop: cropWithRequirements,
        blueprintsLoading: false,
        blueprints: [blueprint({ id: 10, task_type: 'field_work', gdd_trigger: 50 })],
        blueprintsRegenerating: false
      });
      expect(next.showBlueprintReadinessChecklist).toBe(false);
    });

    it('is false while blueprints are regenerating', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        blueprintsLoading: false,
        blueprints: [],
        blueprintsRegenerating: true
      });
      expect(next.showBlueprintReadinessChecklist).toBe(false);
    });
  });

  describe('unassociatedAgriculturalTasks and blueprint enrichment', () => {
    const agriculturalTasks = [
      { id: 1, name: 'Weeding', required_tools: [], is_reference: false },
      { id: 2, name: 'Fertilizing', required_tools: [], is_reference: false },
      { id: 3, name: 'Harvesting', required_tools: [], is_reference: false }
    ];

    it('keeps all agricultural tasks selectable even when already linked to blueprints', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        agriculturalTasks,
        blueprints: [blueprint({ id: 10, agricultural_task_id: 1, gdd_trigger: 50 })]
      });
      expect(next.unassociatedAgriculturalTasks.map((task) => task.id)).toEqual([1, 2, 3]);
    });

    it('requires GDD when adding a second blueprint with the same stage and task', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        agriculturalTasks,
        blueprints: [
          blueprint({ id: 10, agricultural_task_id: 1, stage_order: 1, gdd_trigger: 50 })
        ],
        selectedBlueprintAgriculturalTaskId: 1,
        selectedBlueprintStageOrder: 1,
        blueprintCreateFormAttempted: true,
        blueprintCreateGddTrigger: null
      });
      expect(next.blueprintCreateGddError).toBe('gdd_required');
      expect(next.canCreateBlueprint).toBe(false);
    });

    it('allows creating a second blueprint when GDD distinguishes the slot', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        agriculturalTasks,
        blueprints: [
          blueprint({ id: 10, agricultural_task_id: 1, stage_order: 1, gdd_trigger: 50 })
        ],
        selectedBlueprintAgriculturalTaskId: 1,
        selectedBlueprintStageOrder: 1,
        blueprintCreateGddTrigger: 120,
        blueprintCreateFormAttempted: true
      });
      expect(next.blueprintCreateGddError).toBeNull();
      expect(next.canCreateBlueprint).toBe(true);
    });

    it('enriches blueprints with agricultural task names when blueprint name is missing', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        agriculturalTasks,
        blueprints: [
          blueprint({
            id: 10,
            agricultural_task_id: 2,
            name: undefined,
            agricultural_task: undefined,
            gdd_trigger: 50
          })
        ]
      });
      expect(next.blueprints[0].name).toBe('Fertilizing');
      expect(next.blueprints[0].agricultural_task).toEqual({
        id: 2,
        name: 'Fertilizing',
        description: null,
        is_reference: false
      });
    });

    it('leaves blueprints unchanged when they already have a display name', () => {
      const next = withCropBlueprintDisplayState({
        ...baseControl,
        agriculturalTasks,
        blueprints: [
          blueprint({
            id: 10,
            agricultural_task_id: 2,
            name: 'Custom label',
            gdd_trigger: 50
          })
        ]
      });
      expect(next.blueprints[0].name).toBe('Custom label');
    });
  });

  it('enables canRegenerateBlueprints when readiness is ready and not regenerating', () => {
    const cropWithRequirements = {
      ...baseControl.crop!,
      crop_stages: [
        {
          id: 1,
          crop_id: 1,
          name: '定植期',
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
    };
    const next = withCropBlueprintDisplayState({
      ...baseControl,
      crop: cropWithRequirements,
      blueprints: [blueprint({ id: 10, task_type: 'field_work', gdd_trigger: 50 })]
    });
    expect(next.blueprintReadiness.ready).toBe(true);
    expect(next.canRegenerateBlueprints).toBe(true);
  });
});
