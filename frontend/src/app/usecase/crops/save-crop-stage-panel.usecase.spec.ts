import { of, throwError } from 'rxjs';
import { describe, it, expect, vi } from 'vitest';
import { Crop, CropStage } from '../../domain/crops/crop';
import { CropGateway } from './crop-gateway';
import { CropStageGateway } from './crop-stage-gateway';
import { SaveCropStagePanelOutputPort } from './save-crop-stage-panel.output-port';
import { SaveCropStagePanelUseCase } from './save-crop-stage-panel.usecase';

const baseStage: CropStage = {
  id: 1,
  crop_id: 1,
  name: 'Germination',
  order: 1,
  temperature_requirement: {
    id: 1,
    crop_stage_id: 1,
    base_temperature: 10
  },
  thermal_requirement: {
    id: 1,
    crop_stage_id: 1,
    required_gdd: 100
  },
  sunshine_requirement: null,
  nutrient_requirement: null
} as CropStage;

const reloadedCrop: Crop = {
  id: 1,
  name: 'Tomato',
  crop_stages: [
    {
      ...baseStage,
      name: 'Updated Name',
      temperature_requirement: {
        id: 1,
        crop_stage_id: 1,
        base_temperature: 12
      }
    }
  ]
} as Crop;

function createStageGateway(overrides: Partial<CropStageGateway> = {}): CropStageGateway {
  return {
    createCropStage: () => of(baseStage),
    updateCropStage: vi.fn(() => of({ ...baseStage, name: 'Updated Name' })),
    reorderCropStages: () => of([baseStage]),
    deleteCropStage: () => of(undefined),
    getTemperatureRequirement: () => of(baseStage.temperature_requirement),
    createTemperatureRequirement: () => of(baseStage.temperature_requirement!),
    updateTemperatureRequirement: vi.fn(() =>
      of({
        id: 1,
        crop_stage_id: 1,
        base_temperature: 12
      })
    ),
    deleteTemperatureRequirement: () => of(undefined),
    getThermalRequirement: () => of(baseStage.thermal_requirement),
    createThermalRequirement: () => of(baseStage.thermal_requirement!),
    updateThermalRequirement: vi.fn(() =>
      of({
        id: 1,
        crop_stage_id: 1,
        required_gdd: 150
      })
    ),
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

function createCropGateway(show = vi.fn(() => of(reloadedCrop))): CropGateway {
  return {
    list: () => of([]),
    show,
    create: () => of({} as never),
    update: () => of({} as never),
    destroy: () => of({} as never)
  };
}

describe('SaveCropStagePanelUseCase', () => {
  it('runs stage, temperature, and thermal updates sequentially then reloads crop on full success', () => {
    const callOrder: string[] = [];
    const stageGateway = createStageGateway({
      updateCropStage: vi.fn(() => {
        callOrder.push('stage');
        return of({ ...baseStage, name: 'Updated Name' });
      }),
      updateTemperatureRequirement: vi.fn(() => {
        callOrder.push('temperature');
        return of({
          id: 1,
          crop_stage_id: 1,
          base_temperature: 12
        });
      }),
      updateThermalRequirement: vi.fn(() => {
        callOrder.push('thermal');
        return of({
          id: 1,
          crop_stage_id: 1,
          required_gdd: 150
        });
      })
    });
    const cropGateway = createCropGateway();
    let successDto: { stage: CropStage } | null = null;
    const outputPort: SaveCropStagePanelOutputPort = {
      onSuccess: (dto) => {
        successDto = dto;
      },
      onPanelPartialFailure: () => {},
      onError: () => {}
    };

    const useCase = new SaveCropStagePanelUseCase(outputPort, stageGateway, cropGateway);
    useCase.execute({
      cropId: 1,
      stageId: 1,
      stagePatch: { name: 'Updated Name' },
      temperaturePatch: { base_temperature: 12 },
      thermalPatch: { required_gdd: 150 }
    });

    expect(callOrder).toEqual(['stage', 'temperature', 'thermal']);
    expect(cropGateway.show).toHaveBeenCalledWith(1);
    expect(successDto).not.toBeNull();
    expect(successDto!.stage.name).toBe('Updated Name');
  });

  it('reloads crop and reports partial failure when the second API call fails', () => {
    const stageGateway = createStageGateway({
      updateTemperatureRequirement: vi.fn(() => throwError(() => new Error('temperature save failed')))
    });
    const cropGateway = createCropGateway();
    let partialFailureDto: { crop: Crop; stageId: number } | null = null;
    const outputPort: SaveCropStagePanelOutputPort = {
      onSuccess: () => {},
      onPanelPartialFailure: (dto) => {
        partialFailureDto = dto;
      },
      onError: () => {}
    };

    const useCase = new SaveCropStagePanelUseCase(outputPort, stageGateway, cropGateway);
    useCase.execute({
      cropId: 1,
      stageId: 1,
      stagePatch: { name: 'Updated Name' },
      temperaturePatch: { base_temperature: 12 }
    });

    expect(stageGateway.updateCropStage).toHaveBeenCalledTimes(1);
    expect(stageGateway.updateTemperatureRequirement).toHaveBeenCalledTimes(1);
    expect(cropGateway.show).toHaveBeenCalledWith(1);
    expect(partialFailureDto).not.toBeNull();
    expect(partialFailureDto!.stageId).toBe(1);
    expect(partialFailureDto!.crop).toEqual(reloadedCrop);
  });
});
