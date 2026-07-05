import { describe, expect, it, vi } from 'vitest';
import { of, throwError } from 'rxjs';
import { UpdateCropTaskScheduleBlueprintUseCase } from './update-crop-task-schedule-blueprint.usecase';
import { CropTaskScheduleBlueprintGateway } from './crop-task-schedule-blueprint-gateway';
import {
  UpdateCropTaskScheduleBlueprintOutputPort
} from './crop-task-schedule-blueprint.ports';

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
    const gateway: CropTaskScheduleBlueprintGateway = {
      list: vi.fn(),
      create: vi.fn(),
      regenerate: vi.fn(),
      update: vi.fn(() => throwError(() => ({ status: 422, error: { error_code: 'x' } }))),
      destroy: vi.fn()
    };
    const outputPort: UpdateCropTaskScheduleBlueprintOutputPort = {
      onUpdateStarted: vi.fn(),
      present: vi.fn(),
      onError: vi.fn()
    };

    const useCase = new UpdateCropTaskScheduleBlueprintUseCase(outputPort, gateway);
    useCase.execute({ cropId: 3, blueprintId: 20, gddTrigger: 10 });

    expect(outputPort.onError).toHaveBeenCalled();
  });
});
