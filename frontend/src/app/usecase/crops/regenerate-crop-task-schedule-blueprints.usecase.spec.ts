import { HttpErrorResponse } from '@angular/common/http';
import { TestBed } from '@angular/core/testing';
import { of, throwError } from 'rxjs';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { RegenerateCropTaskScheduleBlueprintsUseCase } from './regenerate-crop-task-schedule-blueprints.usecase';
import { CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY } from './crop-task-schedule-blueprint-gateway';
import { REGENERATE_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT } from './crop-task-schedule-blueprint.ports';

describe('RegenerateCropTaskScheduleBlueprintsUseCase', () => {
  let useCase: RegenerateCropTaskScheduleBlueprintsUseCase;
  let gateway: { regenerate: ReturnType<typeof vi.fn> };
  let outputPort: {
    onRegenerateStarted: ReturnType<typeof vi.fn>;
    present: ReturnType<typeof vi.fn>;
    onError: ReturnType<typeof vi.fn>;
  };

  beforeEach(() => {
    gateway = { regenerate: vi.fn() };
    outputPort = {
      onRegenerateStarted: vi.fn(),
      present: vi.fn(),
      onError: vi.fn()
    };

    TestBed.configureTestingModule({
      providers: [
        RegenerateCropTaskScheduleBlueprintsUseCase,
        { provide: CROP_TASK_SCHEDULE_BLUEPRINT_GATEWAY, useValue: gateway },
        { provide: REGENERATE_CROP_TASK_SCHEDULE_BLUEPRINTS_OUTPUT_PORT, useValue: outputPort }
      ]
    });

    useCase = TestBed.inject(RegenerateCropTaskScheduleBlueprintsUseCase);
  });

  it('maps error_code from API to blueprint error i18n key', () => {
    gateway.regenerate.mockReturnValue(
      throwError(
        () =>
          new HttpErrorResponse({
            status: 422,
            error: { error: 'templates missing', error_code: 'missing_task_templates' }
          })
      )
    );

    useCase.execute({ cropId: 3 });

    expect(outputPort.onRegenerateStarted).toHaveBeenCalled();
    expect(outputPort.onError).toHaveBeenCalledWith({
      message: 'crops.show.blueprint_errors.missing_task_templates'
    });
  });

  it('presents blueprints on success', () => {
    const blueprints = [{ id: 1, crop_id: 3, gdd_trigger: 10 } as never];
    gateway.regenerate.mockReturnValue(of(blueprints));

    useCase.execute({ cropId: 3 });

    expect(outputPort.present).toHaveBeenCalledWith({ blueprints });
  });
});
