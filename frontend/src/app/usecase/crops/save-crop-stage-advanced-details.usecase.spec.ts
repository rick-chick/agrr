import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { Crop, CropStage } from '../../domain/crops/crop';
import { CropGateway } from './crop-gateway';
import { CropStageGateway } from './crop-stage-gateway';
import { SaveCropStageAdvancedDetailsOutputPort } from './save-crop-stage-advanced-details.output-port';
import { SaveCropStageAdvancedDetailsUseCase } from './save-crop-stage-advanced-details.usecase';

const baseStage: CropStage = {
  id: 1,
  crop_id: 1,
  name: 'Germination',
  order: 1,
  temperature_requirement: {
    id: 1,
    crop_stage_id: 1,
    sterility_risk_threshold: null
  },
  thermal_requirement: null,
  sunshine_requirement: {
    id: 1,
    crop_stage_id: 1,
    minimum_sunshine_hours: 4,
    target_sunshine_hours: 8
  },
  nutrient_requirement: {
    id: 1,
    crop_stage_id: 1,
    daily_uptake_n: 0.5,
    daily_uptake_p: 0.2,
    daily_uptake_k: 0.3,
    region: 'jp'
  }
} as CropStage;

const reloadedCrop: Crop = {
  id: 1,
  name: 'Tomato',
  crop_stages: [baseStage]
} as Crop;

function createStageGateway(overrides: Partial<CropStageGateway> = {}): CropStageGateway {
  return {
    createCropStage: () => of(baseStage),
    updateCropStage: () => of(baseStage),
    reorderCropStages: () => of([baseStage]),
    deleteCropStage: () => of(undefined),
    getTemperatureRequirement: () => of(baseStage.temperature_requirement),
    createTemperatureRequirement: () => of(baseStage.temperature_requirement!),
    updateTemperatureRequirement: vi.fn(() =>
      of({
        id: 1,
        crop_stage_id: 1,
        sterility_risk_threshold: 32
      })
    ),
    deleteTemperatureRequirement: () => of(undefined),
    getThermalRequirement: () => of(null),
    createThermalRequirement: () => of({ id: 1, crop_stage_id: 1 }),
    updateThermalRequirement: () => of({ id: 1, crop_stage_id: 1 }),
    deleteThermalRequirement: () => of(undefined),
    getSunshineRequirement: () => of(baseStage.sunshine_requirement),
    createSunshineRequirement: () => of(baseStage.sunshine_requirement!),
    updateSunshineRequirement: vi.fn(() => of(baseStage.sunshine_requirement!)),
    deleteSunshineRequirement: () => of(undefined),
    getNutrientRequirement: () => of(baseStage.nutrient_requirement),
    createNutrientRequirement: () => of(baseStage.nutrient_requirement!),
    updateNutrientRequirement: vi.fn(() => of(baseStage.nutrient_requirement!)),
    deleteNutrientRequirement: () => of(undefined),
    ...overrides
  };
}

function createCropGateway(show = vi.fn(() => of(reloadedCrop))): CropGateway {
  return {
    list: () => of([]),
    show,
    create: () => of({} as never),
    update: () => of({} as never),
    destroy: () => of({} as never)
  };
}

describe('SaveCropStageAdvancedDetailsUseCase', () => {
  it('runs sunshine, nutrient, and temperature updates sequentially on full success', () => {
    const callOrder: string[] = [];
    const stageGateway = createStageGateway({
      updateSunshineRequirement: vi.fn(() => {
        callOrder.push('sunshine');
        return of(baseStage.sunshine_requirement!);
      }),
      updateNutrientRequirement: vi.fn(() => {
        callOrder.push('nutrient');
        return of(baseStage.nutrient_requirement!);
      }),
      updateTemperatureRequirement: vi.fn(() => {
        callOrder.push('temperature');
        return of({
          id: 1,
          crop_stage_id: 1,
          sterility_risk_threshold: 32
        });
      })
    });
    const cropGateway = createCropGateway();
    let successDto: { stage: CropStage } | null = null;
    const outputPort: SaveCropStageAdvancedDetailsOutputPort = {
      onSuccess: (dto) => {
        successDto = dto;
      },
      onAdvancedPartialFailure: () => {},
      onError: () => {}
    };

    const useCase = new SaveCropStageAdvancedDetailsUseCase(outputPort, stageGateway, cropGateway);
    useCase.execute({
      cropId: 1,
      stageId: 1,
      sunshinePatch: { minimum_sunshine_hours: 5, target_sunshine_hours: 9 },
      nutrientPatch: {
        daily_uptake_n: 0.6,
        daily_uptake_p: 0.3,
        daily_uptake_k: 0.4,
        region: 'jp'
      },
      temperaturePatch: { sterility_risk_threshold: 32 }
    });

    expect(callOrder).toEqual(['sunshine', 'nutrient', 'temperature']);
    expect(cropGateway.show).toHaveBeenCalledWith(1);
    expect(successDto).not.toBeNull();
  });

  it('reloads crop and reports partial failure when the second API call fails', () => {
    const stageGateway = createStageGateway({
      updateNutrientRequirement: vi.fn(() => throwError(() => new Error('nutrient save failed')))
    });
    const cropGateway = createCropGateway();
    let partialFailureDto: { crop: Crop; stageId: number } | null = null;
    const outputPort: SaveCropStageAdvancedDetailsOutputPort = {
      onSuccess: () => {},
      onAdvancedPartialFailure: (dto) => {
        partialFailureDto = dto;
      },
      onError: () => {}
    };

    const useCase = new SaveCropStageAdvancedDetailsUseCase(outputPort, stageGateway, cropGateway);
    useCase.execute({
      cropId: 1,
      stageId: 1,
      sunshinePatch: { minimum_sunshine_hours: 5, target_sunshine_hours: 9 },
      nutrientPatch: {
        daily_uptake_n: 0.6,
        daily_uptake_p: 0.3,
        daily_uptake_k: 0.4,
        region: 'jp'
      }
    });

    expect(stageGateway.updateSunshineRequirement).toHaveBeenCalledTimes(1);
    expect(stageGateway.updateNutrientRequirement).toHaveBeenCalledTimes(1);
    expect(cropGateway.show).toHaveBeenCalledWith(1);
    expect(partialFailureDto).not.toBeNull();
    expect(partialFailureDto!.stageId).toBe(1);
    expect(partialFailureDto!.crop).toEqual(reloadedCrop);
  });
});
