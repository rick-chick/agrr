import { HttpErrorResponse } from '@angular/common/http';
import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { CropStage } from '../../domain/crops/crop';
import { CropStageGateway } from './crop-stage-gateway';
import { ReorderCropStagesOutputPort } from './reorder-crop-stages.output-port';
import { ReorderCropStagesUseCase } from './reorder-crop-stages.usecase';

const reorderedStages: CropStage[] = [
  {
    id: 2,
    crop_id: 1,
    name: 'Vegetative',
    order: 1
  } as CropStage,
  {
    id: 1,
    crop_id: 1,
    name: 'Germination',
    order: 2
  } as CropStage
];

describe('ReorderCropStagesUseCase', () => {
  it('presents reordered stages on success', () => {
    const cropStageGateway: CropStageGateway = {
      createCropStage: () => of({} as never),
      updateCropStage: () => of({} as never),
      reorderCropStages: vi.fn(() => of(reorderedStages)),
      deleteCropStage: () => of(undefined),
      getTemperatureRequirement: () => of(null),
      createTemperatureRequirement: () => of({} as never),
      updateTemperatureRequirement: () => of({} as never),
      deleteTemperatureRequirement: () => of(undefined),
      getThermalRequirement: () => of(null),
      createThermalRequirement: () => of({} as never),
      updateThermalRequirement: () => of({} as never),
      deleteThermalRequirement: () => of(undefined),
      getSunshineRequirement: () => of(null),
      createSunshineRequirement: () => of({} as never),
      updateSunshineRequirement: () => of({} as never),
      deleteSunshineRequirement: () => of(undefined),
      getNutrientRequirement: () => of(null),
      createNutrientRequirement: () => of({} as never),
      updateNutrientRequirement: () => of({} as never),
      deleteNutrientRequirement: () => of(undefined)
    };
    let presented: { stages: CropStage[] } | null = null;
    const outputPort: ReorderCropStagesOutputPort = {
      present: (dto) => {
        presented = dto;
      },
      onError: () => {}
    };

    const useCase = new ReorderCropStagesUseCase(outputPort, cropStageGateway);
    useCase.execute({
      cropId: 1,
      entries: [
        { id: 2, order: 1 },
        { id: 1, order: 2 }
      ]
    });

    expect(cropStageGateway.reorderCropStages).toHaveBeenCalledWith(1, [
      { id: 2, order: 1 },
      { id: 1, order: 2 }
    ]);
    expect(presented).toEqual({ stages: reorderedStages });
  });

  it('reports gateway errors via output port with apiErrorI18nKey', () => {
    const reorderError = new HttpErrorResponse({ status: 422, statusText: 'Unprocessable Entity' });
    const cropStageGateway: CropStageGateway = {
      createCropStage: () => of({} as never),
      updateCropStage: () => of({} as never),
      reorderCropStages: () => throwError(() => reorderError),
      deleteCropStage: () => of(undefined),
      getTemperatureRequirement: () => of(null),
      createTemperatureRequirement: () => of({} as never),
      updateTemperatureRequirement: () => of({} as never),
      deleteTemperatureRequirement: () => of(undefined),
      getThermalRequirement: () => of(null),
      createThermalRequirement: () => of({} as never),
      updateThermalRequirement: () => of({} as never),
      deleteThermalRequirement: () => of(undefined),
      getSunshineRequirement: () => of(null),
      createSunshineRequirement: () => of({} as never),
      updateSunshineRequirement: () => of({} as never),
      deleteSunshineRequirement: () => of(undefined),
      getNutrientRequirement: () => of(null),
      createNutrientRequirement: () => of({} as never),
      updateNutrientRequirement: () => of({} as never),
      deleteNutrientRequirement: () => of(undefined)
    };
    let errorMessage: string | null = null;
    const outputPort: ReorderCropStagesOutputPort = {
      present: () => {},
      onError: (dto) => {
        errorMessage = dto.message;
      }
    };

    const useCase = new ReorderCropStagesUseCase(outputPort, cropStageGateway);
    useCase.execute({
      cropId: 1,
      entries: [{ id: 1, order: 1 }]
    });

    expect(errorMessage).toBe('common.api_error.generic');
  });
});
