import { TestBed } from '@angular/core/testing';
import { describe, expect, it, beforeEach } from 'vitest';
import { CropTaskScheduleBlueprintsPresenter } from './crop-task-schedule-blueprints.presenter';
import {
  CropTaskScheduleBlueprintsView,
  CropTaskScheduleBlueprintsViewState
} from '../../components/masters/crops/crop-task-schedule-blueprints.view';
import { LoadCropTaskScheduleBlueprintsDataDto } from '../../usecase/crops/crop-task-schedule-blueprint.ports';
import { withCropBlueprintDisplayState } from './crop-blueprints-display-state';
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
    stage_name: 'Stage 1',
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

const baseControl: CropTaskScheduleBlueprintsViewState = withCropBlueprintDisplayState({
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
        name: 'Stage 1',
        order: 1,
        thermal_requirement: { id: 1, crop_stage_id: 1, required_gdd: 200 }
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
  blueprintsLoading: true,
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
});

describe('CropTaskScheduleBlueprintsPresenter', () => {
  let presenter: CropTaskScheduleBlueprintsPresenter;
  let lastControl: CropTaskScheduleBlueprintsViewState;
  let view: CropTaskScheduleBlueprintsView;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CropTaskScheduleBlueprintsPresenter]
    });
    presenter = TestBed.inject(CropTaskScheduleBlueprintsPresenter);
    lastControl = { ...baseControl };
    view = {
      get control(): CropTaskScheduleBlueprintsViewState {
        return lastControl;
      },
      set control(value: CropTaskScheduleBlueprintsViewState) {
        lastControl = value;
      },
      reload: () => {}
    };
    presenter.setView(view);
  });

  it('applyLocalControl updates control via withCropBlueprintDisplayState', () => {
    lastControl = {
      ...baseControl,
      blueprints: [blueprint({ id: 10, gdd_trigger: 50 })],
      blueprintGddDrafts: { 10: 500 }
    };

    presenter.applyLocalControl({ blueprintGddTouched: { 10: true } });

    expect(lastControl.blueprintGddTouched).toEqual({ 10: true });
    expect(lastControl.blueprintGddErrors).toEqual({ 10: 'out_of_range' });
  });

  it('presents blueprint list with drafts and clears loading', () => {
    const dto: LoadCropTaskScheduleBlueprintsDataDto = {
      blueprints: [blueprint({ id: 10, gdd_trigger: 80 }), blueprint({ id: 11, gdd_trigger: 120 })]
    };

    presenter.present(dto);

    expect(lastControl.blueprintsLoading).toBe(false);
    expect(lastControl.blueprints).toEqual(dto.blueprints);
    expect(lastControl.blueprintGddDrafts).toEqual({ 10: 80, 11: 120 });
    expect(lastControl.blueprintGddTouched).toEqual({});
  });

  it('onRegenerateStarted sets blueprintsRegenerating to true', () => {
    presenter.onRegenerateStarted();
    expect(lastControl.blueprintsRegenerating).toBe(true);
  });

  it('onError stores inline blueprint regenerate error when regenerating', () => {
    lastControl = { ...baseControl, blueprintsRegenerating: true };

    presenter.onError({ message: 'crops.show.blueprint_errors.generic' });

    expect(lastControl.blueprintsRegenerating).toBe(false);
    expect(lastControl.blueprintRegenerateError).toBe('crops.show.blueprint_errors.generic');
    expect(lastControl.pendingErrorFlash).toBeNull();
  });

  it('onError sets pending error flash for non-blueprint errors', () => {
    presenter.onError({ message: 'crops.flash.load_failed' });

    expect(lastControl.blueprintRegenerateError).toBeNull();
    expect(lastControl.pendingErrorFlash).not.toBeNull();
    expect(lastControl.pendingErrorFlash?.text).toBe('crops.flash.load_failed');
  });
});
