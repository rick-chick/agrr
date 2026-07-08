import { HttpErrorResponse } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { CreateCropTaskScheduleBlueprintUseCase } from './create-crop-task-schedule-blueprint.usecase';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from './crop-task-schedule-blueprint-gateway';
import { CREATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT } from './crop-task-schedule-blueprint.ports';

describe('CreateCropTaskScheduleBlueprintUseCase', () => {
  let useCase: CreateCropTaskScheduleBlueprintUseCase;
  let gateway: { create: ReturnType<typeof vi.fn> };
  let outputPort: {
    present: ReturnType<typeof vi.fn>;
    onError: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    gateway = { create: vi.fn() };
    outputPort = {
      present: vi.fn(),
      onError: vi.fn()
    };

    TestBed.configureTestingModule({
      providers: [
        CreateCropTaskScheduleBlueprintUseCase,
        { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useValue: gateway },
        { provide: CREATE_CROP_TASK_SCHEDULE_BLUEPRINT_OUTPUT_PORT, useValue: outputPort }
      ]
    });

    useCase = TestBed.inject(CreateCropTaskScheduleBlueprintUseCase);
  });

  it('presents created blueprint on success', () => {
    const blueprint = { id: 21, crop_id: 3, gdd_trigger: 120 } as never;
    gateway.create.mockReturnValue(of(blueprint));

    useCase.execute({
      cropId: 3,
      agriculturalTaskId: 5,
      stageOrder: 1,
      stageName: 'Vegetative',
      gddTrigger: 120
    });

    expect(gateway.create).toHaveBeenCalledWith(3, {
      agricultural_task_id: 5,
      stage_order: 1,
      stage_name: 'Vegetative',
      gdd_trigger: 120
    });
    expect(outputPort.present).toHaveBeenCalledWith({ blueprint });
  });

  it('maps API error to i18n key via output port on failure', () => {
    gateway.create.mockReturnValue(
      throwError(
        () =>
          new HttpErrorResponse({
            status: 422,
            error: { error: 'duplicate', error_code: 'duplicate_blueprint' }
          })
      )
    );

    useCase.execute({
      cropId: 3,
      agriculturalTaskId: 5,
      stageOrder: 1,
      stageName: 'Vegetative',
      gddTrigger: 120
    });

    expect(outputPort.onError).toHaveBeenCalled();
    expect(outputPort.present).not.toHaveBeenCalled();
  });
});
