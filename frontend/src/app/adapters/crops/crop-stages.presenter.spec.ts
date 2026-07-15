import { TestBed } from '@angular/core/testing';
import { CropStagesPresenter } from './crop-stages.presenter';
import { CropStagesView, CropStagesViewState } from '../../components/masters/crops/crop-stages.view';
import { LoadCropForEditDataDto } from '../../usecase/crops/load-crop-for-edit.dtos';
import { LoadCropTaskScheduleBlueprintsDataDto } from '../../usecase/crops/crop-task-schedule-blueprint.ports';
import { CreateCropStageOutputDto } from '../../usecase/crops/create-crop-stage.dtos';
import { UpdateCropStageOutputDto } from '../../usecase/crops/update-crop-stage.dtos';
import { DeleteCropStageOutputDto } from '../../usecase/crops/delete-crop-stage.dtos';
import { UpdateTemperatureRequirementOutputDto } from '../../usecase/crops/update-temperature-requirement.dtos';
import { UpdateThermalRequirementOutputDto } from '../../usecase/crops/update-thermal-requirement.dtos';
import { UpdateSunshineRequirementOutputDto } from '../../usecase/crops/update-sunshine-requirement.dtos';
import { UpdateNutrientRequirementOutputDto } from '../../usecase/crops/update-nutrient-requirement.dtos';
import { CropStage } from '../../domain/crops/crop';
import { defaultBlueprintReadiness } from '../../domain/crops/blueprint-generation-readiness';

describe('CropStagesPresenter', () => {
  let presenter: CropStagesPresenter;
  let view: CropStagesView;
  let lastControl: CropStagesViewState | null;

  const emptyFormData: CropStagesViewState['formData'] = {
    name: '',
    crop_stages: []
  };

  const baseControlState = (
    formData: CropStagesViewState['formData'] = emptyFormData
  ): CropStagesViewState => ({
    loading: false,
    error: null,
    pendingErrorFlash: null,
    pendingSuccessFlash: null,
    pendingReorderCropStagesSnapshot: null,
    blueprintReadiness: defaultBlueprintReadiness(),
    taskScheduleBlueprints: [],
    formData
  });

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [CropStagesPresenter]
    });
    presenter = TestBed.inject(CropStagesPresenter);
    lastControl = null;
    view = {
      get control(): CropStagesViewState {
        return lastControl ?? {
          loading: true,
          error: null,
          pendingErrorFlash: null,
          pendingSuccessFlash: null,
          pendingReorderCropStagesSnapshot: null,
          blueprintReadiness: defaultBlueprintReadiness(),
          taskScheduleBlueprints: [],
          formData: emptyFormData
        };
      },
      set control(value: CropStagesViewState) {
        lastControl = value;
      }
    };
    presenter.setView(view);
  });

  describe('LoadCropForEditOutputPort', () => {
    it('updates view.control with crop name and stages on present(dto)', () => {
      const dto: LoadCropForEditDataDto = {
        crop: {
          id: 1,
          name: 'Test Crop',
          variety: null,
          area_per_unit: null,
          revenue_per_area: null,
          region: null,
          groups: [],
          is_reference: false,
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              temperature_requirement: {
                id: 1,
                crop_stage_id: 1,
                base_temperature: 10.0
              }
            }
          ]
        }
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.loading).toBe(false);
      expect(lastControl!.formData.name).toBe('Test Crop');
      expect(lastControl!.formData.crop_stages).toEqual(dto.crop.crop_stages);
    });
  });

  describe('LoadCropTaskScheduleBlueprintsOutputPort', () => {
    it('updates view.control.taskScheduleBlueprints on present(dto)', () => {
      const dto: LoadCropTaskScheduleBlueprintsDataDto = {
        blueprints: [
          {
            id: 1,
            crop_id: 1,
            agricultural_task_id: 1,
            source_agricultural_task_id: null,
            stage_order: 1,
            stage_name: 'Stage 1',
            gdd_trigger: 0,
            gdd_tolerance: null,
            task_type: 'general',
            source: 'manual',
            priority: 1,
            amount: null,
            amount_unit: null,
            description: null,
            weather_dependency: null,
            time_per_sqm: null
          }
        ]
      };

      presenter.present(dto);

      expect(lastControl).not.toBeNull();
      expect(lastControl!.taskScheduleBlueprints).toEqual(dto.blueprints);
    });
  });

  describe('CreateCropStageOutputPort', () => {
    it('adds new stage to formData.crop_stages on present(dto)', () => {
      lastControl = baseControlState({
          name: 'Test Crop',
          crop_stages: [{ id: 1, crop_id: 1, name: 'Stage 1', order: 1 }]
      });

      const newStage: CropStage = {
        id: 2,
        crop_id: 1,
        name: 'Stage 2',
        order: 2
      };
      const dto: CreateCropStageOutputDto = { stage: newStage };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages).toHaveLength(2);
      expect(lastControl!.formData.crop_stages[1]).toEqual(newStage);
      expect(lastControl!.pendingSuccessFlash).toEqual({ type: 'success', text: 'crops.flash.stage_created' });
    });
  });

  describe('UpdateCropStageOutputPort', () => {
    it('updates existing stage in formData.crop_stages on present(dto)', () => {
      lastControl = baseControlState({
          name: 'Test Crop',
          crop_stages: [{ id: 1, crop_id: 1, name: 'Stage 1', order: 1 }]
      });

      const updatedStage: CropStage = {
        id: 1,
        crop_id: 1,
        name: 'Updated Stage 1',
        order: 1
      };
      const dto: UpdateCropStageOutputDto = { stage: updatedStage };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages).toHaveLength(1);
      expect(lastControl!.formData.crop_stages[0]).toEqual(updatedStage);
      expect(lastControl!.pendingSuccessFlash).toEqual({ type: 'success', text: 'crops.flash.stage_updated' });
    });
  });

  describe('DeleteCropStageOutputPort', () => {
    it('queues pending success flash on present(dto)', () => {
      lastControl = baseControlState({
          name: 'Test Crop',
          crop_stages: [{ id: 1, crop_id: 1, name: 'Stage 1', order: 1 }]
      });

      const dto: DeleteCropStageOutputDto = { success: true, stageId: 1 };

      presenter.present(dto);

      expect(lastControl!.pendingSuccessFlash).toEqual({ type: 'success', text: 'crops.flash.stage_deleted' });
    });
  });

  describe('UpdateTemperatureRequirementOutputPort', () => {
    it('updates temperature_requirement of the corresponding stage on present(dto)', () => {
      lastControl = baseControlState({
          name: 'Test Crop',
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              temperature_requirement: {
                id: 1,
                crop_stage_id: 1,
                base_temperature: 10.0
              }
            }
          ]
      });

      const dto: UpdateTemperatureRequirementOutputDto = {
        requirement: {
          id: 1,
          crop_stage_id: 1,
          base_temperature: 15.0,
          optimal_min: 20.0
        }
      };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages[0].temperature_requirement).toEqual(dto.requirement);
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'crops.flash.temperature_requirement_updated'
      });
    });
  });

  describe('UpdateThermalRequirementOutputPort', () => {
    it('updates thermal_requirement of the corresponding stage on present(dto)', () => {
      lastControl = baseControlState({
          name: 'Test Crop',
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              thermal_requirement: {
                id: 1,
                crop_stage_id: 1,
                required_gdd: 100.0
              }
            }
          ]
      });

      const dto: UpdateThermalRequirementOutputDto = {
        requirement: {
          id: 1,
          crop_stage_id: 1,
          required_gdd: 150.0
        }
      };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages[0].thermal_requirement).toEqual(dto.requirement);
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'crops.flash.thermal_requirement_updated'
      });
    });
  });

  describe('UpdateSunshineRequirementOutputPort', () => {
    it('updates sunshine_requirement of the corresponding stage on present(dto)', () => {
      lastControl = baseControlState({
          name: 'Test Crop',
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              sunshine_requirement: {
                id: 1,
                crop_stage_id: 1,
                minimum_sunshine_hours: 5.0
              }
            }
          ]
      });

      const dto: UpdateSunshineRequirementOutputDto = {
        requirement: {
          id: 1,
          crop_stage_id: 1,
          minimum_sunshine_hours: 6.0,
          target_sunshine_hours: 8.0
        }
      };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages[0].sunshine_requirement).toEqual(dto.requirement);
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'crops.flash.sunshine_requirement_updated'
      });
    });
  });

  describe('ReorderCropStagesOutputPort', () => {
    it('restores crop stage order on onError when reorder snapshot exists', () => {
      const originalStages: CropStage[] = [
        { id: 1, crop_id: 1, name: 'Stage 1', order: 1 },
        { id: 2, crop_id: 1, name: 'Stage 2', order: 2 }
      ];
      const reorderedStages: CropStage[] = [
        { id: 2, crop_id: 1, name: 'Stage 2', order: 1 },
        { id: 1, crop_id: 1, name: 'Stage 1', order: 2 }
      ];
      lastControl = baseControlState({
        name: 'Test Crop',
        crop_stages: reorderedStages
      });
      lastControl = {
        ...lastControl!,
        pendingReorderCropStagesSnapshot: originalStages
      };

      presenter.onError({ message: 'network error' });

      expect(lastControl!.formData.crop_stages).toEqual(originalStages);
      expect(lastControl!.pendingReorderCropStagesSnapshot).toBeNull();
      expect(lastControl!.pendingErrorFlash).toEqual({
        type: 'error',
        text: 'network error'
      });
    });
  });

  describe('UpdateNutrientRequirementOutputPort', () => {
    it('updates nutrient_requirement of the corresponding stage on present(dto)', () => {
      lastControl = baseControlState({
          name: 'Test Crop',
          crop_stages: [
            {
              id: 1,
              crop_id: 1,
              name: 'Stage 1',
              order: 1,
              nutrient_requirement: {
                id: 1,
                crop_stage_id: 1,
                daily_uptake_n: 1.0
              }
            }
          ]
      });

      const dto: UpdateNutrientRequirementOutputDto = {
        requirement: {
          id: 1,
          crop_stage_id: 1,
          daily_uptake_n: 1.5,
          daily_uptake_p: 0.5,
          daily_uptake_k: 1.2,
          region: 'Test Region'
        }
      };

      presenter.present(dto);

      expect(lastControl!.formData.crop_stages[0].nutrient_requirement).toEqual(dto.requirement);
      expect(lastControl!.pendingSuccessFlash).toEqual({
        type: 'success',
        text: 'crops.flash.nutrient_requirement_updated'
      });
    });
  });
});
