import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { CropStage } from '../../domain/crops/crop';
import { CropStageGateway } from './crop-stage-gateway';
import { CreateCropStageOutputPort } from './create-crop-stage.output-port';
import { CreateCropStageUseCase } from './create-crop-stage.usecase';
import { DeleteCropStageOutputPort } from './delete-crop-stage.output-port';
import { DeleteCropStageUseCase } from './delete-crop-stage.usecase';
import { ReorderCropStagesOutputPort } from './reorder-crop-stages.output-port';
import { ReorderCropStagesUseCase } from './reorder-crop-stages.usecase';

const baseStage: CropStage = {
  id: 1,
  crop_id: 1,
  name: 'Germination',
  order: 1
};

function createStageGateway(overrides: Partial<CropStageGateway> = {}): CropStageGateway {
  return {
    createCropStage: () => of(baseStage),
    updateCropStage: () => of(baseStage),
    reorderCropStages: () => of([baseStage]),
    deleteCropStage: () => of(undefined),
    getTemperatureRequirement: () => of(null),
    createTemperatureRequirement: () => of({ id: 1, crop_stage_id: 1 }),
    updateTemperatureRequirement: () => of({ id: 1, crop_stage_id: 1 }),
    deleteTemperatureRequirement: () => of(undefined),
    getThermalRequirement: () => of(null),
    createThermalRequirement: () => of({ id: 1, crop_stage_id: 1 }),
    updateThermalRequirement: () => of({ id: 1, crop_stage_id: 1 }),
    deleteThermalRequirement: () => of(undefined),
    getSunshineRequirement: () => of(null),
    createSunshineRequirement: () => of({ id: 1, crop_stage_id: 1 }),
    updateSunshineRequirement: () => of({ id: 1, crop_stage_id: 1 }),
    deleteSunshineRequirement: () => of(undefined),
    getNutrientRequirement: () => of(null),
    createNutrientRequirement: () => of({ id: 1, crop_stage_id: 1 }),
    updateNutrientRequirement: () => of({ id: 1, crop_stage_id: 1 }),
    deleteNutrientRequirement: () => of(undefined),
    ...overrides
  };
}

const networkError = new HttpErrorResponse({ status: 0, statusText: 'Unknown Error' });

describe('crop stage CRUD use cases api error i18n', () => {
  it('CreateCropStageUseCase passes apiErrorI18nKey to onError on gateway failure', () => {
    const stageGateway = createStageGateway({
      createCropStage: vi.fn(() => throwError(() => networkError))
    });
    let errorMessage: string | null = null;
    const outputPort: CreateCropStageOutputPort = {
      present: () => {},
      onError: (dto) => {
        errorMessage = dto.message;
      }
    };

    const useCase = new CreateCropStageUseCase(outputPort, stageGateway);
    useCase.execute({ cropId: 1, payload: { name: 'Stage 2', order: 2 } });

    expect(errorMessage).toBe('common.api_error.network');
  });

  it('ReorderCropStagesUseCase passes apiErrorI18nKey to onError on gateway failure', () => {
    const stageGateway = createStageGateway({
      reorderCropStages: vi.fn(() => throwError(() => networkError))
    });
    let errorMessage: string | null = null;
    const outputPort: ReorderCropStagesOutputPort = {
      present: () => {},
      onError: (dto) => {
        errorMessage = dto.message;
      }
    };

    const useCase = new ReorderCropStagesUseCase(outputPort, stageGateway);
    useCase.execute({ cropId: 1, entries: [{ id: 1, order: 1 }] });

    expect(errorMessage).toBe('common.api_error.network');
  });

  it('DeleteCropStageUseCase passes apiErrorI18nKey to onError on gateway failure', () => {
    const stageGateway = createStageGateway({
      deleteCropStage: vi.fn(() => throwError(() => networkError))
    });
    let errorMessage: string | null = null;
    const outputPort: DeleteCropStageOutputPort = {
      present: () => {},
      onError: (dto) => {
        errorMessage = dto.message;
      }
    };

    const useCase = new DeleteCropStageUseCase(outputPort, stageGateway);
    useCase.execute({ cropId: 1, stageId: 1 });

    expect(errorMessage).toBe('common.api_error.network');
  });
});
