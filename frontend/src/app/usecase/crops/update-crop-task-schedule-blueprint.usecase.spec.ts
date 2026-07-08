import { describe, expect, it, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { UpdateCropTaskScheduleBlueprintUseCase } from './update-crop-task-schedule-blueprint.usecase';
import { CropTaskScheduleBlueprintGateway } from './crop-task-schedule-blueprint-gateway';
import {
  UpdateCropTaskScheduleBlueprintOutputPort
} from './crop-task-schedule-blueprint.ports';
import type { CropTaskScheduleBlueprint } from '../../domain/crops/crop-task-schedule-blueprint';

function blueprint(
  overrides: Partial<CropTaskScheduleBlueprint> & Pick<CropTaskScheduleBlueprint, 'id'>
): CropTaskScheduleBlueprint {
  return {
    crop_id: 3,
    agricultural_task_id: 5,
    source_agricultural_task_id: null,
    stage_order: null,
    stage_name: null,
    gdd_trigger: null,
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

function createUseCase(
  gatewayUpdate = vi.fn(() =>
    of({
      id: 20,
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
    })
  )
) {
  const gateway: CropTaskScheduleBlueprintGateway = {
    list: vi.fn(),
    create: vi.fn(),
    regenerate: vi.fn(),
    update: gatewayUpdate,
    destroy: vi.fn()
  };
  const outputPort: UpdateCropTaskScheduleBlueprintOutputPort = {
    onUpdateStarted: vi.fn(),
    present: vi.fn(),
    onError: vi.fn()
  };
  return {
    useCase: new UpdateCropTaskScheduleBlueprintUseCase(outputPort, gateway),
    gateway,
    outputPort
  };
}

describe('UpdateCropTaskScheduleBlueprintUseCase', () => {
  it('resolves stage_name from cropStages when stageOrder is provided', () => {
    const gateway: CropTaskScheduleBlueprintGateway = {
      list: vi.fn(),
      create: vi.fn(),
      regenerate: vi.fn(),
      update: vi.fn(() =>
        of({
          id: 20,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 2,
          stage_name: 'Flowering',
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
        })
      ),
      destroy: vi.fn()
    };
    const outputPort: UpdateCropTaskScheduleBlueprintOutputPort = {
      onUpdateStarted: vi.fn(),
      present: vi.fn(),
      onError: vi.fn()
    };

    const useCase = new UpdateCropTaskScheduleBlueprintUseCase(outputPort, gateway);
    useCase.execute({
      cropId: 3,
      blueprintId: 20,
      stageOrder: 2,
      cropStages: [
        { order: 1, name: 'Vegetative' },
        { order: 2, name: 'Flowering' }
      ]
    });

    expect(gateway.update).toHaveBeenCalledWith(3, 20, {
      stage_order: 2,
      stage_name: 'Flowering'
    });
    expect(outputPort.present).toHaveBeenCalled();
  });

  it('sends null stage_name when stageOrder is null', () => {
    const gateway: CropTaskScheduleBlueprintGateway = {
      list: vi.fn(),
      create: vi.fn(),
      regenerate: vi.fn(),
      update: vi.fn(() =>
        of({
          id: 20,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: null,
          stage_name: null,
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
        })
      ),
      destroy: vi.fn()
    };
    const outputPort: UpdateCropTaskScheduleBlueprintOutputPort = {
      onUpdateStarted: vi.fn(),
      present: vi.fn(),
      onError: vi.fn()
    };

    const useCase = new UpdateCropTaskScheduleBlueprintUseCase(outputPort, gateway);
    useCase.execute({
      cropId: 3,
      blueprintId: 20,
      stageOrder: null,
      cropStages: [{ order: 1, name: 'Vegetative' }]
    });

    expect(gateway.update).toHaveBeenCalledWith(3, 20, {
      stage_order: null,
      stage_name: null
    });
  });

  it('patches gdd_trigger when provided', () => {
    const gateway: CropTaskScheduleBlueprintGateway = {
      list: vi.fn(),
      create: vi.fn(),
      regenerate: vi.fn(),
      update: vi.fn(() =>
        of({
          id: 20,
          crop_id: 3,
          agricultural_task_id: 5,
          source_agricultural_task_id: null,
          stage_order: 1,
          stage_name: 'Vegetative',
          gdd_trigger: 150,
          gdd_tolerance: null,
          task_type: 'field_work',
          source: 'manual',
          priority: 1,
          amount: null,
          amount_unit: null,
          description: null,
          weather_dependency: null,
          time_per_sqm: null
        })
      ),
      destroy: vi.fn()
    };
    const outputPort: UpdateCropTaskScheduleBlueprintOutputPort = {
      onUpdateStarted: vi.fn(),
      present: vi.fn(),
      onError: vi.fn()
    };

    const useCase = new UpdateCropTaskScheduleBlueprintUseCase(outputPort, gateway);
    useCase.execute({ cropId: 3, blueprintId: 20, gddTrigger: 150 });

    expect(gateway.update).toHaveBeenCalledWith(3, 20, { gdd_trigger: 150 });
  });

  it('reports gateway errors via output port', () => {
    const { useCase, outputPort } = createUseCase(
      vi.fn(() => throwError(() => ({ status: 422, error: { error_code: 'x' } })))
    );

    useCase.execute({ cropId: 3, blueprintId: 20, gddTrigger: 10 });

    expect(outputPort.onError).toHaveBeenCalled();
  });

  describe('executeDrop', () => {
    const cropStages = [
      { order: 1, name: 'Vegetative' },
      { order: 2, name: 'Flowering' }
    ];

    it('patches stage when dropped onto another stage lane', () => {
      const dragged = blueprint({ id: 20, stage_order: 1, gdd_trigger: 120 });
      const { useCase, gateway } = createUseCase();

      useCase.executeDrop({
        cropId: 3,
        dragged,
        targetStageOrder: null,
        laneBlueprints: [],
        dropIndex: 0,
        cropStages
      });

      expect(gateway.update).toHaveBeenCalledWith(3, 20, {
        stage_order: null,
        stage_name: null
      });
    });

    it('patches gdd_trigger when dropped within the same lane to a new position', () => {
      const laneBlueprints = [
        blueprint({ id: 30, stage_order: 1, gdd_trigger: 50 }),
        blueprint({ id: 20, stage_order: 1, gdd_trigger: 120 }),
        blueprint({ id: 31, stage_order: 1, gdd_trigger: 200 })
      ];
      const { useCase, gateway } = createUseCase();

      useCase.executeDrop({
        cropId: 3,
        dragged: laneBlueprints[2],
        targetStageOrder: 1,
        laneBlueprints,
        dropIndex: 1,
        cropStages
      });

      expect(gateway.update).toHaveBeenCalledWith(3, 31, { gdd_trigger: 50 });
    });

    it('patches stage and gdd_trigger when dropped onto another stage lane with neighbors', () => {
      const vegetativeLane = [blueprint({ id: 20, stage_order: 1, gdd_trigger: 120 })];
      const dragged = blueprint({ id: 22, stage_order: null, gdd_trigger: 10 });
      const { useCase, gateway } = createUseCase();

      useCase.executeDrop({
        cropId: 3,
        dragged,
        targetStageOrder: 1,
        laneBlueprints: vegetativeLane,
        dropIndex: 0,
        cropStages
      });

      expect(gateway.update).toHaveBeenCalledWith(3, 22, {
        stage_order: 1,
        stage_name: 'Vegetative',
        gdd_trigger: 120
      });
    });

    it('does not call gateway when stage and gdd are unchanged', () => {
      const dragged = blueprint({ id: 20, stage_order: 1, gdd_trigger: 120 });
      const lane = [dragged];
      const { useCase, gateway } = createUseCase();

      useCase.executeDrop({
        cropId: 3,
        dragged,
        targetStageOrder: 1,
        laneBlueprints: lane,
        dropIndex: 0,
        cropStages
      });

      expect(gateway.update).not.toHaveBeenCalled();
    });
  });
});
